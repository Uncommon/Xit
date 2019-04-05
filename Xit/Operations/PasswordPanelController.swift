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
  var storeInKeychain: Bool
  {
    get { return keychainCheck.boolValue }
    set { keychainCheck.boolValue = newValue }
  }
  
  @IBOutlet weak var userField: NSTextField!
  @IBOutlet weak var passwordField: NSSecureTextField!
  @IBOutlet weak var keychainCheck: NSButton!
}
