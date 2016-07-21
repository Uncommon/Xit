import Cocoa
import Siesta

class XTRemoteSheetController: XTSheetController {
  
  var repository: XTRepository? = nil
  
  @IBOutlet weak var nameField: NSTextField!
  @IBOutlet weak var fetchField: NSTextField!
  @IBOutlet weak var pushField: NSTextField!
  
  var name: String
  {
    get { return nameField.stringValue }
    set { nameField.stringValue = newValue }
  }
  var fetchURL: NSURL?
  {
    get { return NSURL(string: fetchField.stringValue) }
    set { fetchField.stringValue = newValue?.absoluteString ?? "" }
  }
  var pushURL: NSURL?
    {
    get { return NSURL(string: pushField.stringValue) }
    set { pushField.stringValue = newValue?.absoluteString ?? "" }
  }
  
  override func resetFields()
  {
    name = ""
    fetchURL = nil
    pushURL = nil
  }
  
  override func accept(sender: AnyObject)
  {
    // validate the fields
    
    super.accept(sender)
  }
}
