import Cocoa


enum PasswordAction {
  case Save
  case Change
  case UseExisting
}


class XTAccountsPrefsController: NSViewController {
  
  @IBOutlet weak var addController: XTAddAccountController!
  @IBOutlet weak var accountsTable: NSTableView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    XTAccountsManager.manager.readAccounts()
  }
  
  func showError(message: String)
  {
    let alert = NSAlert()
    
    alert.messageText = message
    alert.beginSheetModalForWindow(view.window!) { (NSModalResponse) in }
  }
  
  @IBAction func addAccount(sender: AnyObject)
  {
    addController.resetFields()
    view.window?.beginSheet(addController.window!) { (response) in
      guard response == NSModalResponseOK else { return }
      guard let url = self.addController.location
      else { return }
      
      self.addAccount(self.addController.accountType,
                      user: self.addController.userName,
                      password: self.addController.password,
                      location: url)
    }
  }
  
  func addAccount(type: AccountType, user: String, password: String, location: NSURL)
  {
    var passwordAction = PasswordAction.Save
    
    if let oldPassword = XTKeychain.findPassword(location, account: user) {
      if oldPassword == password {
        passwordAction = .UseExisting
      }
      else {
        let alert = NSAlert()
        
        alert.messageText =
            "There is already a password for that account in the keychain. " +
            "Do you want to change it, or use the existing password?"
        alert.addButtonWithTitle("Change")
        alert.addButtonWithTitle("Use existing")
        alert.addButtonWithTitle("Cancel")
        alert.beginSheetModalForWindow(view.window!) { (response) in
          switch response {
            case NSAlertFirstButtonReturn:
              self.finishAddAccount(.Change, type: type, user: user,
                                    password: password, location: location)
            case NSAlertSecondButtonReturn:
              self.finishAddAccount(.UseExisting, type: type, user: user,
                                    password: "", location: location)
            default:
              break
          }
        }
        return
      }
    }
    finishAddAccount(passwordAction, type: type, user: user, password: password,
                     location: location)
  }
  
  func finishAddAccount(action: PasswordAction, type: AccountType,
                        user: String, password: String, location: NSURL)
  {
    switch action {
      case .Save:
        do {
          try XTKeychain.savePassword(location, account: user, password: password)
        }
        catch _ as XTKeychain.Error {
          showError("The password could not be saved because the location field is incorrect.")
          return
        }
        catch _ as NSError {
          showError("The password could not be saved to the Keychain.")
          return
        }
      
      case .Change:
        do {
          try XTKeychain.changePassword(location, account: user,
                                        password: password)
        }
        catch _ as NSError {
          showError("The password could not be saved to the Keychain.")
          return
        }
      
      default:
        break
    }
    
    XTAccountsManager.manager.add(Account(type: type,
                                  user: user,
                                  location: location))
    accountsTable.reloadData()
  }
  
  @IBAction func removeAccount(sender: AnyObject)
  {
    XTAccountsManager.manager.accounts.removeAtIndex(accountsTable.selectedRow)
    accountsTable.reloadData()
  }
  
  func numberOfRowsInTableView(tableView: NSTableView) -> Int
  {
    return XTAccountsManager.manager.accounts.count
  }
  
  func tableView(tableView: NSTableView,
                 viewForTableColumn tableColumn: NSTableColumn?,
                 row: Int) -> NSView?
  {
    guard let tableColumn = tableColumn
    else { return nil }
    
    let view = tableView.makeViewWithIdentifier(tableColumn.identifier,
                                                owner: self)
               as! NSTableCellView
    let account = XTAccountsManager.manager.accounts[row]
    
    switch tableColumn.identifier {
      case "service":
        view.textField?.stringValue = account.type.displayName
        view.imageView?.image = NSImage(named: account.type.imageName)
      case "userName":
        view.textField?.stringValue = account.user
      case "location":
        view.textField?.stringValue = account.location.absoluteString
      default:
        return nil
    }
    return view
  }
}
