import Cocoa

/// Controller for the "new account" sheet
class XTAddAccountController: XTSheetController {
  
  @IBOutlet private weak var servicePopup: NSPopUpButton!
  @IBOutlet private weak var userField: NSTextField!
  @IBOutlet private weak var passwordField: NSSecureTextField!
  @IBOutlet private weak var locationField: NSTextField!
  
  override var window: NSWindow?
  {
    didSet
    {
      window?.addObserver(self, forKeyPath: "firstResponder",
                          options: .New, context: nil)
    }
  }
  
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
  
  override func observeValueForKeyPath(
      keyPath: String?, ofObject object: AnyObject?,
      change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>)
  {
    guard (object != nil) && ((object! as! NSObject) == window) &&
          (keyPath != nil) && (keyPath == "firstResponder")
    else { return }
    guard let change = change,
          let newResponder = change[NSKeyValueChangeNewKey] as? NSView
              where newResponder == passwordField
    else { return }
    
    passwordFocused()
  }
  
  func showFieldAlert(message: String, field: NSView)
  {
    let alert = NSAlert()
    
    alert.alertStyle = .CriticalAlertStyle
    alert.messageText = message
    alert.beginSheetModalForWindow((window?.sheetParent)!) { (response) in
      self.window?.makeFirstResponder(field)
    }
  }
  
  override func accept(sender: AnyObject)
  {
    guard userName != ""
    else {
      showFieldAlert("The user field must not be empty.",
                     field: userField)
      return
    }
    
    guard location != nil
    else {
      showFieldAlert("The location field must have a valid URL.",
                     field: locationField)
      return
    }
    
    super.accept(sender)
  }
  
  func passwordFocused()
  {
    guard userName != "",
          let location = location,
          let newPassword = XTKeychain.findPassword(location, account: userName)
    else { return }
    
    password = newPassword
  }
  
  @IBAction func serviceChanged(sender: AnyObject)
  {
    syncLocationField()
  }
  
  override func resetFields()
  {
    userField.stringValue = ""
    passwordField.stringValue = ""
    syncLocationField()
    window?.makeFirstResponder(userField)
  }
  
  func syncLocationField()
  {
    locationField.stringValue = accountType.defaultLocation
  }

}
