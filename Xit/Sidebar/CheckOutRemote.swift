import Cocoa

class CheckOutRemoteOperationController: XTOperationController
{
  let remoteBranch: String
  let sheetController: CheckOutRemoteWindowController
  
  init(windowController: XTWindowController, branch: String)
  {
    self.remoteBranch = branch
    self.sheetController =
        CheckOutRemoteWindowController(repo: windowController.repository)
    
    super.init(windowController: windowController)
  }
  
  override func start() throws
  {
    sheetController.setRemoteBranchName(remoteBranch)
    windowController!.window?.beginSheet(sheetController.window!) {
      (response) in
      guard response == .OK
      else { return }
      // make the local branch and fetch
    }
  }
}

class CheckOutRemoteWindowController: NSWindowController
{
  @IBOutlet weak var promptLabel: NSTextField!
  @IBOutlet weak var nameField: NSTextField!
  @IBOutlet weak var createButton: NSButton!
  
  let repo: Branching
  
  override var windowNibName: NSNib.Name? { return ◊"CheckOutRemote" }
  
  init(repo: Branching)
  {
    self.repo = repo
    super.init(window: nil)
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  func setRemoteBranchName(_ remoteBranch: String)
  {
    loadWindow()
    promptLabel.stringValue = "Create a local branch tracking \"\(remoteBranch)\""
    nameField.stringValue = remoteBranch.deletingFirstPathComponent
  }
  
  func endSheet(_ result: NSApplication.ModalResponse)
  {
    guard let window = self.window,
          let parent = window.sheetParent
    else { return }
    
    parent.endSheet(window, returnCode: result)
  }

  @IBAction func cancelSheet(_ sender: Any)
  {
    endSheet(.cancel)
  }
  
  @IBAction func create(_ sender: Any)
  {
    endSheet(.OK)
  }
  
  @objc
  override func controlTextDidChange(_ obj: Notification)
  {
    let branchName = nameField.stringValue
    
    createButton.isEnabled = XTRefFormatter.isValidRefString(branchName) &&
                             repo.localBranch(named: branchName) == nil
  }
}
