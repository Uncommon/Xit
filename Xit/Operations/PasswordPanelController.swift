import Cocoa

class PasswordPanelController: SheetController
{
  var userName: String
  {
    get { return userField.stringValue }
    set { userField.stringValue = newValue }
  }
  var password: String
  {
    get { return passwordField.stringValue }
    set { passwordField.stringValue = newValue }
  }
  
  @IBOutlet weak var userField: NSTextField!
  @IBOutlet weak var passwordField: NSSecureTextField!
}
