import Cocoa
import Siesta

class XTRemoteSheetController: XTSheetController
{
  weak var repository: XTRepository? = nil
  
  @IBOutlet weak var nameField: NSTextField!
  @IBOutlet weak var fetchField: NSTextField!
  @IBOutlet weak var pushField: NSTextField!
  
  var name: String
  {
    get { return nameField.stringValue }
    set { nameField.stringValue = newValue }
  }
  var fetchURL: URL?
  {
    get { return URL(string: fetchField.stringValue) }
    set { fetchField.stringValue = newValue?.absoluteString ?? "" }
  }
  var pushURL: URL?
    {
    get { return URL(string: pushField.stringValue) }
    set { pushField.stringValue = newValue?.absoluteString ?? "" }
  }
  
  override func resetFields()
  {
    name = ""
    fetchURL = nil
    pushURL = nil
  }
  
  override func accept(_ sender: AnyObject)
  {
    // validate the fields
    
    super.accept(sender)
  }
}
