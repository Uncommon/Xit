import Foundation


extension XTRepository {
  
  func credentialProvider(passwordBlock: () -> (String, String)?)
      -> GTCredentialProvider
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
      
      if let (userName, password) = passwordBlock(),
         let result = try? GTCredential(userName: userName,
                                        password: password) {
        return result
      }
      return GTCredential()
    }
  }
  
  /// Initiates a fetch operation.
  /// - parameter remote: The remote to pull from.
  /// - parameter downloadTags: True to also download tags
  /// - parameter pruneBranches: True to delete obsolete branch refs
  /// - parameter passwordBlock: Callback for getting the user and password
  /// - parameter progressBlock: Return true to stop the operation
  public func fetch(remote remote: XTRemote,
                    downloadTags: Bool,
                    pruneBranches: Bool,
                    passwordBlock: () -> (String, String)?,
                    progressBlock: (git_transfer_progress) -> Bool) throws
  {
    let tagOption = downloadTags ? GTRemoteDownloadTagsAuto
                                 : GTRemoteDownloadTagsNone
    let pruneOption: GTFetchPruneOption = pruneBranches ? .Yes : .No
    let pruneValue = NSNumber(long: pruneOption.rawValue)
    let tagValue = NSNumber(unsignedInt: tagOption.rawValue)
    let provider = self.credentialProvider(passwordBlock)
    let options = [
        GTRepositoryRemoteOptionsDownloadTags: tagValue,
        GTRepositoryRemoteOptionsFetchPrune: pruneValue,
        GTRepositoryRemoteOptionsCredentialProvider: provider]
  
    try gtRepo.fetchRemote(remote, withOptions: options) { (progress, stop) in
      if progressBlock(progress.memory) {
        stop.memory = true
      }
    }
  }
  
  /// Initiates pulling the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter options: Options for fetch.
  /// - parameter progressBlock: Progress callback. Return true to stop.
  public func pullBranch(branch: XTBranch,
                         remote: XTRemote,
                         options: [String: AnyObject],
                         progressBlock: (git_transfer_progress) -> Bool) throws
  {
    try gtRepo.pullBranch(branch.gtBranch, fromRemote: remote, withOptions: options) {
      (progress: UnsafePointer<git_transfer_progress>,
       stop: UnsafeMutablePointer<ObjCBool>) in
      stop.memory = ObjCBool(progressBlock(progress.memory))
    }
  }
}

// MARK: Credential helpers

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
