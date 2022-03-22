import Cocoa
import Siesta

protocol RemoteSheetDelegate: AnyObject
{
  func acceptSettings(from sheetController: RemoteSheetController) -> Bool
}

final class RemoteSheetController: SheetController
{
  weak var delegate: (any RemoteSheetDelegate)?
  
  @IBOutlet weak var nameField: NSTextField!
  @IBOutlet weak var fetchField: NSTextField!
  @IBOutlet weak var pushField: NSTextField!
  
  @ControlStringValue var name: String
  var fetchURLString: String?
  {
    get { fetchField.stringValue.nilIfEmpty }
    set { fetchField.stringValue = newValue ?? "" }
  }
  var pushURLString: String?
  {
    get { pushField.stringValue.nilIfEmpty }
    set { pushField.stringValue = newValue ?? "" }
  }
  
  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    $name = nameField
  }
  
  override func resetFields()
  {
    name = ""
    fetchURLString = nil
    pushURLString = nil
  }
  
  override func accept(_ sender: AnyObject)
  {
    if delegate?.acceptSettings(from: self) ?? false {
      super.accept(sender)
    }
  }
}
