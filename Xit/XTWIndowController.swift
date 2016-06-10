import Cocoa

class XTWindowController: NSWindowController {
  @IBOutlet var historyController: XTHistoryViewController!
  @IBOutlet var activity: NSProgressIndicator!
  var xtDocument: XTDocument?
  var selectedCommitSHA: String?
  var inStagingView: Bool { return self.selectedCommitSHA == XTStagingSHA }
  
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
    
    repo.addObserver(self, forKeyPath: "activeTasks", options: .New, context: nil)
    self.historyController.windowDidLoad()
    self.historyController.setRepo(repo)
  }
  
  override func observeValueForKeyPath(
      keyPath: String?,
      ofObject object: AnyObject?,
      change: [String : AnyObject]?,
      context: UnsafeMutablePointer<Void>)
  {
    guard let keyPath = keyPath else { return }
    guard keyPath == "activeTasks" else { return }
    
    if let tasks = change?[NSKeyValueChangeNewKey] {
      if tasks.count > 0 {
        self.activity.startAnimation(self)
      }
      return
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
}
