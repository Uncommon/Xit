import Cocoa


/// Takes charge of an asyncronous action such as network operations
class XTOperationController: NSObject {

  /// The window controller that initiated and owns the operation. May be nil
  /// if the window is closed before the operation completes.
  weak var windowController: XTWindowController?
  /// Convenient reference to the repository from the window controller.
  let repository: XTRepository
  /// True if the operation is being canceled for some reason.
  var canceled = false
  
  init(windowController: XTWindowController)
  {
    self.windowController = windowController
    self.repository = windowController.xtDocument!.repository
  }
}


/// Runs a `fetch` operation.
class XTFetchController: XTOperationController {
  
  func defaultRemoteName() -> String?
  {
    guard let remotes = try? repository.remoteNames()
    else { return nil }
    
    switch remotes.count {
      case 0:
        return nil
      case 1:
        return remotes[0]
      default:
        for remote in remotes {
          if remote == "origin" {
            return remote
          }
        }
        return remotes[0]
    }
  }
  
  func defaultPrune(remote: String) -> Bool
  {
    // TODO: Provide encapsulated config access from XTRepository
    guard let config = try? repository.gtRepo.configuration()
    else { return false}
    
    if config.boolForKey("remote.\(remote).prune") {
      return true
    }
    return config.boolForKey("fetch.prune")
  }
  
  func start()
  {
    let panel = XTFetchPanelController.controller()
    
    if let remoteName = defaultRemoteName() {
      panel.selectedRemote = remoteName
    }
    panel.parentController = self.windowController
    panel.downloadTags = false
    panel.pruneBranches = defaultPrune(panel.selectedRemote as String)
    self.windowController!.window!.beginSheet(panel.window!) { (response) in
      if response == NSModalResponseOK {
        let pruneBranches = panel.pruneBranches
            ? GTFetchPruneOption.Yes
            : GTFetchPruneOption.No
        
        self.executeFetch(panel.selectedRemote as String,
                          downloadTags: panel.downloadTags,
                          pruneBranches: pruneBranches)
      }
      else {
        self.ended()
      }
    }
  }
  
  func ended()
  {
    self.windowController?.fetchEnded()
  }
  
  func credentialProvider() -> GTCredentialProvider
  {
    return GTCredentialProvider() {
        (type, url, user) -> GTCredential in
      if checkCredentialType(type, flag: .SSHKey) {
        return sshCredential(user) ?? GTCredential()
      }
      
      guard checkCredentialType(type, flag: .UserPassPlaintext)
      else { return GTCredential() }
      
      if let password = keychainPassword(url, user: user) {
        do {
          return try GTCredential(userName: user, password: password)
        }
        catch let error as NSError {
          NSLog(error.description)
        }
      }
      
      guard let window = self.windowController?.window
      else { return GTCredential() }
      
      let panel = XTPasswordPanelController.controller()
      let semaphore = dispatch_semaphore_create(0)
      var result: GTCredential?
      
      dispatch_async(dispatch_get_main_queue()) {
        window.beginSheet(panel.window!) { (response) in
          if response == NSModalResponseOK {
            result = try? GTCredential(userName: panel.userName,
                                       password: panel.password)
          }
          _ = dispatch_semaphore_signal(semaphore)
        }
      }
      dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
      return result ?? GTCredential()
    }
  }
  
  func executeFetch(remoteName: String,
                    downloadTags: Bool,
                    pruneBranches: GTFetchPruneOption)
  {
    guard let remote = try? repository.remote(remoteName)
    else { return }
    
    XTStatusView.update(
        status: "Fetching", progress: 0.0, repository: repository)
    
    let repo = repository  // For use in the block without being tied to self
    
    repo.executeOffMainThread {
      do {
        let provider = self.credentialProvider()
        let options: [String: AnyObject] = [
            GTRepositoryRemoteOptionsDownloadTags: Int(downloadTags),
            GTRepositoryRemoteOptionsFetchPrune: pruneBranches.rawValue,
            GTRepositoryRemoteOptionsCredentialProvider: provider,
            ]
        
        try repo.gtRepo.fetchRemote(remote, withOptions: options) {
            (progress, stop) in
          if self.canceled {
            stop.memory = true
          }
          else {
            let progressValue =
                progress.memory.received_objects == progress.memory.total_objects
                ? -1.0
                : Float(progress.memory.total_objects) /
                  Float(progress.memory.received_objects)
            
            XTStatusView.update(
              status: "Fetching", progress: progressValue, repository: repo)
          }
        }
        XTStatusView.update(
          status: "Fetch complete", progress: -1, repository: repo)
      }
      catch let error as NSError {
        dispatch_async(dispatch_get_main_queue()) {
          XTStatusView.update(
            status: "Fetch failed", progress: -1, repository: repo)
          
          if let window = self.windowController?.window {
            let alert = NSAlert(error: error)
            
            // needs to be smarter: look at error type
            alert.beginSheetModalForWindow(window, completionHandler: nil)
          }
        }
      }
      self.ended()
    }
  }
}


func checkCredentialType(type: GTCredentialType,
                         flag: GTCredentialType) -> Bool
{
  return (type.rawValue & flag.rawValue) != 0
}

func keychainPassword(urlString: String, user: String) -> String?
{
  guard let url = NSURL(string: urlString),
        let server = url.host as NSString?
  else { return nil }
  
  let user = user as NSString
  var passwordLength: UInt32 = 0
  var passwordData: UnsafeMutablePointer<Void> = nil
  
  let err = SecKeychainFindInternetPassword(
      nil,
      UInt32(server.length), server.UTF8String,
      0, nil,
      UInt32(user.length), user.UTF8String,
      0, nil, 0,
      .Any, .Default,
      &passwordLength, &passwordData, nil)
  
  if err != noErr {
    return nil
  }
  return NSString(bytes: passwordData,
                  length: Int(passwordLength),
                  encoding: NSUTF8StringEncoding) as String?
}

func sshCredential(user: String) -> GTCredential?
{
  let publicPath =
      ("~/.ssh/id_rsa.pub" as NSString).stringByExpandingTildeInPath
  let privatePath =
      ("~/.ssh/id_rsa" as NSString).stringByExpandingTildeInPath
  
  return try? GTCredential(
      userName: user,
      publicKeyURL: NSURL(fileURLWithPath: publicPath),
      privateKeyURL: NSURL(fileURLWithPath: privatePath),
      passphrase: "")
}
