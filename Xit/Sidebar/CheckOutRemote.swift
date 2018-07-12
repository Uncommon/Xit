import Cocoa

class CheckOutRemoteOperationController: XTOperationController
{
  let remoteBranch: String
  var sheetController: CheckOutRemoteWindowController!
  
  init(windowController: XTWindowController, branch: String)
  {
    self.remoteBranch = branch
    
    super.init(windowController: windowController)

    self.sheetController =
        CheckOutRemoteWindowController(repo: windowController.repository,
                                       operation: self)
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
  @IBOutlet weak var errorLabel: NSTextField!
  @IBOutlet weak var nameField: NSTextField!
  @IBOutlet weak var createButton: NSButton!
  
  let repo: Branching
  unowned let operation: CheckOutRemoteOperationController
  
  override var windowNibName: NSNib.Name? { return ◊"CheckOutRemote" }
  
  init(repo: Branching, operation: CheckOutRemoteOperationController)
  {
    self.repo = repo
    self.operation = operation
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
    updateCreateButton()
  }
  
  func endSheet(_ result: NSApplication.ModalResponse)
  {
    guard let window = self.window,
          let parent = window.sheetParent
    else { return }
    
    parent.endSheet(window, returnCode: result)
    operation.ended()
  }
  
  func updateCreateButton()
  {
    let branchName = nameField.stringValue
    let refName = "refs/heads/" + branchName
    var errorText = ""
    
    if !XTRefFormatter.isValidRefString(refName) {
      errorText = "Not a valid name"
    }
    if repo.localBranch(named: branchName) != nil {
      errorText = "Branch already exists"
    }
    
    errorLabel.stringValue = errorText
    createButton.isEnabled = errorText.isEmpty
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
    updateCreateButton()
  }
}
