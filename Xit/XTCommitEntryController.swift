import Cocoa

/// Handles the commit message entry area.
class XTCommitEntryController: NSViewController
{
  weak var repo: XTRepository!
  {
    didSet
    {
      indexObserver = NotificationCenter.default.addObserver(
          forName: .XTRepositoryIndexChanged,
          object: repo,
          queue: .main) {
        [weak self] _ in
        self?.updateStagedStatus()
      }
      resetMessage()
    }
  }
  @IBOutlet weak var commitField: NSTextView!
  @IBOutlet weak var commitButton: NSButton!
  @IBOutlet weak var amendChcekbox: NSButton!
  @IBOutlet weak var placeholder: NSTextField!
  
  var indexObserver: NSObjectProtocol?
  
  var repoController: RepositoryController?
  {
    return view.ancestorWindow?.windowController as? RepositoryController
  }
  
  var anyStaged = false
  {
    didSet
    {
      if anyStaged != oldValue {
        updateCommitButton()
      }
    }
  }
  
  var commitMessage: String
  {
    get
    {
      return commitField.string ?? ""
    }
    set
    {
      commitField.string = newValue.trimmingWhitespace
      updateCommitButton()
    }
  }
  
  deinit
  {
    NotificationCenter.default.removeObserver(self)
    indexObserver.map { NotificationCenter.default.removeObserver($0) }
  }
  
  override func awakeFromNib()
  {
    commitField.textContainerInset = NSSize(width: 10, height: 5)
  }
  
  func commitMessageTemplate() -> String?
  {
    guard let templatePath = repo.config.commitTemplate()
    else { return nil }
    
    return try? String(contentsOfFile: templatePath)
  }
  
  func resetMessage()
  {
    commitMessage = commitMessageTemplate() ?? ""
  }
  
  override func viewDidLoad()
  {
    // The editor doesn't allow setting the font of an empty text view.
    commitField.font = placeholder.font
  }
  
  override func viewWillAppear()
  {
    updateStagedStatus()
    updateCommitButton()
  }
  
  @IBAction func commit(_ sender: NSButton)
  {
    do {
      try repo.commit(message: commitField.string,
                      amend: repoController?.isAmending ?? false,
                      outputBlock: nil)
      resetMessage()
    }
    catch {
      let alert = NSAlert(error: error as NSError)
      
      alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
  }
  
  @IBAction func toggleAmend(_ sender: NSButton)
  {
    let newValue = sender.boolValue
  
    if newValue,
       let headCommit = repo.headSHA.flatMap({ repo.commit(forSHA: $0 ) }),
       let headMessage = headCommit.message?.trimmingWhitespace {
      let message = commitMessage
      
      if message.isEmpty || message == commitMessageTemplate() {
        commitMessage = headMessage
      }
      else if message != headMessage {
        guard let window = view.window
        else { return }
        let alert = NSAlert()
        
        alert.messageText = "Replace the commit message?"
        alert.informativeText = """
            Do you want to replace the commit message with the message from
            the previous commit?
            """
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Don't Replace")
        alert.beginSheetModal(for: window) {
          (response) in
          if response == .alertFirstButtonReturn {
            self.commitMessage = headMessage
          }
          self.repoController?.isAmending = newValue
        }
        return
      }
    }
    repoController?.isAmending = newValue
  }
  
  func updateStagedStatus()
  {
    guard let changes = repoController?.selectedModel?.changes
    else {
      anyStaged = false
      return
    }
    
    anyStaged = changes.first(where: { $0.change != .unmodified }) != nil
  }
  
  func updateCommitButton()
  {
    let text = commitField.string
    let emptyText = text.isEmpty
    
    placeholder.isHidden = !emptyText
    
    if anyStaged {
      let whitespace = CharacterSet.whitespacesAndNewlines
      let onlyWhitespace = text.trimmingCharacters(in: whitespace).isEmpty
      
      commitButton.isEnabled = !onlyWhitespace
    }
    else {
      commitButton.isEnabled = false
    }
  }
}

extension XTCommitEntryController: NSTextDelegate
{
  func textDidChange(_ obj: Notification)
  {
    updateCommitButton()
  }
}
