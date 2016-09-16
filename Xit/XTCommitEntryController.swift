import Cocoa

class XTCommitEntryController: NSViewController {

  weak var repo: XTRepository!
  @IBOutlet weak var commitField: NSTextField!
  @IBOutlet weak var commitButton: NSButton!
  
  override func viewDidLoad() {
      super.viewDidLoad()
      // Do view setup here.
  }
  
  @IBAction func commit(_ sender: NSButton) {
    do {
      try repo.commit(withMessage: commitField.stringValue,
                      amend: false,
                      outputBlock: nil)
      commitField.stringValue = ""
    }
    catch {
      let alert = NSAlert(error: error as NSError)
      
      alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
  }
  
  override func controlTextDidChange(_ obj: Notification) {
    commitButton.isEnabled = (commitField.stringValue != "")
  }
}
