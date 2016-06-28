import Cocoa

class XTWindowController: NSWindowController {
  
  class OperationStatus { var canceled = false }
  
  @IBOutlet var historyController: XTHistoryViewController!
  @IBOutlet var activity: NSProgressIndicator!
  var xtDocument: XTDocument?
  var selectedCommitSHA: String?
  var selectedModel: XTFileChangesModel?
  var inStagingView: Bool { return self.selectedCommitSHA == XTStagingSHA }
  var operationStatus: OperationStatus?
  
  override var document: AnyObject? {
    didSet {
      xtDocument = document as! XTDocument?
    }
  }
  
  override func windowDidLoad()
  {
    super.windowDidLoad()
    self.window!.contentViewController = self.historyController
    self.window!.makeFirstResponder(self.historyController.historyTable)
    
    let repo = self.xtDocument!.repository
    
    repo.addObserver(self, forKeyPath:"activeTasks", options:.New, context:nil)
    self.historyController.windowDidLoad()
    self.historyController.setRepo(repo)
  }
  
  deinit
  {
    self.xtDocument!.repository.removeObserver(
        self, forKeyPath:"actaiveTasks")
  }
  
  override func observeValueForKeyPath(
      keyPath: String?,
      ofObject object: AnyObject?,
      change: [String : AnyObject]?,
      context: UnsafeMutablePointer<Void>)
  {
    guard keyPath! == "activeTasks"
    else {
      super.observeValueForKeyPath(
          keyPath, ofObject:object, change:change, context:context)
      return
    }
    
    if let tasks = change?[NSKeyValueChangeNewKey] {
      if tasks.count > 0 {
        self.activity.startAnimation(self)
        return
      }
    }
    self.activity.stopAnimation(self)
  }
  
  @IBAction func refresh(_: AnyObject)
  {
    NSNotificationCenter.defaultCenter().postNotificationName(
        XTRepositoryChangedNotification, object: self.xtDocument!.repository)
  }
  
  @IBAction func newTag(_: AnyObject) {}
  @IBAction func newBranch(_: AnyObject) {}
  @IBAction func addRemote(_: AnyObject) {}
  @IBAction func fetch(_: AnyObject)
  {
    guard let repo = xtDocument?.repository
    else { return }
    guard let remotes = try? repo.remoteNames()
    else { return }
    
    if remotes.count == 1 {
      if let remote = try? repo.remote(remotes[0]) {
        self.fetch(remote: remote)
      }
    }
    else {
      // put up a dialog to select the remote
    }
  }
  @IBAction func pull(_: AnyObject) {}
  @IBAction func push(_: AnyObject) {}
  
  @IBAction func networkSegmentClicked(sender: AnyObject)
  {
    switch (sender as! NSSegmentedControl).selectedSegment {
      case 0:
        fetch(sender)
      case 1:
        pull(sender)
      case 2:
        push(sender)
      default:
        break
    }
  }
  
  
  override func close()
  {
    if let status = operationStatus {
      status.canceled = true
    }
    super.close()
  }
  
  func fetch(remote remote: XTRemote)
  {
    let panel = XTFetchPanelController.controller()
    
    _ = panel.window  // force load
    panel.parentController = self
    panel.selectedRemote = remote.name!
    panel.downloadTags = false
    // set the prune check
    self.window?.beginSheet(panel.window!) { (response) in
      if response == NSModalResponseOK {
        self.startFetchTask(panel.selectedRemote as String,
                            downloadTags: panel.downloadTags,
                            pruneBranches: panel.pruneBranches)
      }
    }
  }
  
  func startFetchTask(remoteName: String,
                      downloadTags: Bool,
                      pruneBranches: Bool)
  {
    guard let repo = xtDocument?.repository,
          let remote = try? repo.remote(remoteName)
    else { return }
    
    let status = OperationStatus()
    
    operationStatus = status
    XTStatusView.update(status: "Fetching", progress: 0.0, repository: repo)
    
    repo.executeOffMainThread { [weak self] in
      do {
        let options = [GTRepositoryRemoteOptionsDownloadTags: downloadTags,
                       GTRepositoryRemoteOptionsFetchPrune: pruneBranches]
        
        try repo.gtRepo.fetchRemote(remote, withOptions: options) {
            (progress, stop) in
          if status.canceled {
            stop.memory = true
          }
          else {
            let progressValue = progress.memory.received_objects ==
                                progress.memory.total_objects
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
          
          if let window = self?.window {
            let alert = NSAlert(error: error)
            
            // needs to be smarter: look at error type
            alert.beginSheetModalForWindow(window, completionHandler: nil)
          }
        }
      }
      self?.operationStatus = nil
    }
  }
}
