import Cocoa

/// Controller for the "new account" sheet
class AddAccountController: SheetController
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
  { AccountType(rawValue: servicePopup.indexOfSelectedItem)! }
  @ControlStringValue var userName: String
  @ControlStringValue var password: String
  @ControlURLValue var location: URL?
  
  override func awakeFromNib()
  {
    super.awakeFromNib()
    
    $userName = userField
    $password = passwordField
    $location = locationField

    let menu = servicePopup.menu!

    menu.removeAllItems()
    for accountType in AccountType.allCases {
      let item = menu.addItem(withTitleString: accountType.displayName,
                              action: nil, keyEquivalent: "")

      item.image = NSImage(named: accountType.imageName)
    }
  }
  
  func showFieldAlert(_ message: String, field: NSView)
  {
    let alert = NSAlert()
    
    alert.alertStyle = .critical
    alert.messageText = message
    alert.beginSheetModal(for: (window?.sheetParent)!) {
      (_) in
      self.window?.makeFirstResponder(field)
    }
  }
  
  override func accept(_ sender: AnyObject)
  {
    guard !userName.isEmpty
    else {
      showFieldAlert("The user field must not be empty.",
                     field: userField)
      return
    }
    
    guard !accountType.needsLocation || location != nil
    else {
      showFieldAlert("The location field must have a valid URL.",
                     field: locationField)
      return
    }
    
    super.accept(sender)
  }
  
  func passwordFocused()
  {
    // Weird type inference workaround
    let userName: String! = self.userName
    guard !userName.isEmpty,
          let location = location,
          let newPassword = XTKeychain.shared.find(url: location,
                                                   account: userName)
    else { return }
    
    password = newPassword
  }
  
  @IBAction
  func serviceChanged(_ sender: AnyObject)
  {
    syncLocationField()
  }
  
  override func resetFields()
  {
    servicePopup.selectItem(at: 0)
    userField.stringValue = ""
    passwordField.stringValue = ""
    syncLocationField()
    window?.makeFirstResponder(userField)
  }
  
  func resetForAdd()
  {
    resetFields()
    acceptButton!.titleString = .add
  }
  
  func loadFieldsForEdit(from account: Account)
  {
    if let index = AccountType.allCases.firstIndex(of: account.type) {
      servicePopup.selectItem(at: index)
    }
    userField.stringValue = account.user
    locationField.stringValue = account.location.absoluteString
    passwordField.stringValue = XTKeychain.shared.find(url: account.location,
                                                       account: account.user)
                                ?? ""
    acceptButton!.titleString = .save
  }
  
  func syncLocationField()
  {
    locationField.stringValue = accountType.defaultLocation
    locationField.isEnabled = accountType.needsLocation
  }
}
