import Cocoa

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
}

extension XTCommitEntryController: NSTextDelegate
{
  func textDidChange(_ obj: Notification)
  {
    commitButton.isEnabled = commitField.string.flatMap({
        !$0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty })
        ?? false
    placeholder.isHidden = commitField.string.flatMap({ $0 != "" }) ?? false
  }
}
