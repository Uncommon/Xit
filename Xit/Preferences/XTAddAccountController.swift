import Cocoa

/// Controller for the "new account" sheet
class XTAddAccountController: SheetController
{
  @IBOutlet private weak var servicePopup: NSPopUpButton!
  @IBOutlet private weak var userField: NSTextField!
  @IBOutlet private weak var passwordField: NSSecureTextField!
  @IBOutlet private weak var locationField: NSTextField!
  
  private var responderObserver: NSKeyValueObservation?
  
  override var window: NSWindow?
  {
    didSet
    {
      if let window = self.window {
        responderObserver = window.observe(\.firstResponder, options: [.new]) {
          [weak self] (_, change) in
          guard let newResponder = change.newValue,
                newResponder === self?.passwordField
          else { return }
          
          self?.passwordFocused()
        }
      }
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
  var location: URL?
  {
    get { return URL(string: locationField.stringValue) }
    set { locationField.stringValue = (newValue?.absoluteString)! }
  }
  
  func showFieldAlert(_ message: String, field: NSView)
  {
    let alert = NSAlert()
    
    alert.alertStyle = .critical
    alert.messageText = message
    alert.beginSheetModal(for: (window?.sheetParent)!) { (_) in
      self.window?.makeFirstResponder(field)
    }
  }
  
  override func accept(_ sender: AnyObject)
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
          let newPassword = XTKeychain.findPassword(url: location,
                                                    account: userName)
    else { return }
    
    password = newPassword
  }
  
  @IBAction func serviceChanged(_ sender: AnyObject)
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
