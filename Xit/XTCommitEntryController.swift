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
  @IBOutlet weak var placeholder: NSTextField!
  
  var indexObserver: NSObjectProtocol?
  
  var anyStaged = false
  {
    didSet
    {
      if anyStaged != oldValue {
        updateCommitButton()
      }
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
    commitField.string = commitMessageTemplate() ?? ""
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
  
  @IBAction func commit(_ sender: NSButton) {
    do {
      try repo.commit(message: commitField.string,
                      amend: false,
                      outputBlock: nil)
      resetMessage()
    }
    catch {
      let alert = NSAlert(error: error as NSError)
      
      alert.beginSheetModal(for: view.window!, completionHandler: nil)
    }
  }
  
  func updateStagedStatus()
  {
    guard let controller = view.ancestorWindow?.windowController
                           as? XTWindowController,
          let changes = controller.selection?.fileList.changes
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
