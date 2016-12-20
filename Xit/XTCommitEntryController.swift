import Cocoa

/// Handles the commit message entry area.
class XTCommitEntryController: NSViewController
{
  weak var repo: XTRepository!
  {
    didSet
    {
      indexObserver = NotificationCenter.default.addObserver(
          forName: NSNotification.Name.XTRepositoryIndexChanged,
          object: repo,
          queue: .main) {
        _ in
        self.updateStagedStatus()
      }
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
      guard let message = commitField.string
      else { return }
    
      try repo.commit(withMessage: message,
                      amend: false,
                      outputBlock: nil)
      commitField.string = ""
    }
    catch {
      let alert = NSAlert(error: error as NSError)
      
      alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
  }
  
  func updateStagedStatus()
  {
    guard let controller = view.ancestorWindow?.windowController
                           as? XTWindowController,
          let changes = controller.selectedModel?.changes
    else {
      anyStaged = false
      return
    }
    
    anyStaged = changes.first(where: { $0.change != .unmodified }) != nil
  }
  
  func updateCommitButton()
  {
    let text = commitField.string
    let emptyText = text?.isEmpty ?? true
    
    placeholder.isHidden = !emptyText
    
    if anyStaged {
      let whitespace = CharacterSet.whitespacesAndNewlines
      let onlyWhitespace = text?.trimmingCharacters(in: whitespace).isEmpty
                           ?? true
      
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
