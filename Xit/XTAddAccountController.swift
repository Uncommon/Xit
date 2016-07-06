import Cocoa

/// Controller for the "new account" sheet
class XTAddAccountController: XTSheetController {
  
  @IBOutlet private weak var servicePopup: NSPopUpButton!
  @IBOutlet private weak var userField: NSTextField!
  @IBOutlet private weak var passwordField: NSSecureTextField!
  @IBOutlet private weak var locationField: NSTextField!
  
  var accountType: AccountType
  {
    return AccountType(rawValue: servicePopup.indexOfSelectedItem)!
  }
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
  var location: NSURL?
  {
    get { return NSURL(string: locationField.stringValue) }
    set { locationField.stringValue = (newValue?.absoluteString)! }
  }
  
  @IBAction func serviceChanged(sender: AnyObject)
  {
    locationField.stringValue = accountType.defaultLocation
  }
  
}
