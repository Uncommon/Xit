import Cocoa

class PasswordPanelController: SheetController
{
  @ControlStringValue var userName: String
  @ControlStringValue var password: String
  @ControlBoolValue var storeInKeychain: Bool
  
  @IBOutlet weak var userField: NSTextField!
  @IBOutlet weak var passwordField: NSSecureTextField!
  @IBOutlet weak var keychainCheck: NSButton!
  
  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    $userName = userField
    $password = passwordField
    $storeInKeychain = keychainCheck
  }
}
