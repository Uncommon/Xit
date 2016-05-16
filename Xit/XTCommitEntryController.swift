import Cocoa

class XTCommitEntryController: NSViewController {

  weak var repo: XTRepository!
  @IBOutlet weak var commitField: NSTextField!
  @IBOutlet weak var commitButton: NSButton!
  
  override func viewDidLoad() {
      super.viewDidLoad()
      // Do view setup here.
  }
  
  @IBAction func commit(sender: NSButton) {
    do {
      try repo.commitWithMessage(commitField.stringValue,
                                 amend: false,
                                 outputBlock: nil)
      commitField.stringValue = ""
    }
    catch {
      let alert = NSAlert(error: error as NSError)
      
      alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
    }
  }
  
  override func controlTextDidChange(obj: NSNotification) {
    commitButton.enabled = (commitField.stringValue != "")
  }
}
