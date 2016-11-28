import Cocoa

/// Handles the commit message entry area.
class XTCommitEntryController: NSViewController
{
  weak var repo: XTRepository!
  @IBOutlet weak var commitField: NSTextView!
  @IBOutlet weak var commitButton: NSButton!
  @IBOutlet weak var placeholder: NSTextField!
  
  override func viewDidLoad()
  {
    // The editor doesn't allow setting the font of an empty text view.
    commitField.font = placeholder.font
  }
  
  override func viewWillAppear()
  {
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
  
  func updateCommitButton()
  {
    let text = commitField.string
    let whitespace = CharacterSet.whitespacesAndNewlines
    let onlyWhitespace = text?.trimmingCharacters(in: whitespace).isEmpty
                         ?? true
    let emptyText = text?.isEmpty ?? true
    
    commitButton.isEnabled = !onlyWhitespace
    placeholder.isHidden = !emptyText
  }
}

extension XTCommitEntryController: NSTextDelegate
{
  func textDidChange(_ obj: Notification)
  {
    updateCommitButton()
  }
}
