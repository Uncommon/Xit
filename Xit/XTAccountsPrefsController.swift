import Cocoa


enum PasswordAction
{
  case save
  case change
  case useExisting
}


class XTAccountsPrefsController: NSViewController, PreferencesSaver
{
  // Not a weak reference because there are no other references to it.
  @IBOutlet var addController: XTAddAccountController!
  @IBOutlet weak var accountsTable: NSTableView!
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    let notificationCenter = NotificationCenter.default
    
    XTAccountsManager.manager.readAccounts()
    notificationCenter.addObserver(
        forName: NSNotification.Name(rawValue: XTBasicAuthService.AuthenticationStatusChangedNotification),
        object: nil,
        queue: OperationQueue.main) { (_) in
      self.accountsTable.reloadData()
    }
    notificationCenter.addObserver(
        forName: NSNotification.Name.NSWindowDidResignKey,
        object: self.view.window,
        queue: nil) { (_) in
      self.savePreferences()
    }
  }
  
  deinit
  {
    NotificationCenter.default.removeObserver(self)
  }
  
  func savePreferences()
  {
    XTAccountsManager.manager.saveAccounts()
  }
  
  func showError(_ message: String)
  {
    let alert = NSAlert()
    
    alert.messageText = message
    alert.beginSheetModal(for: view.window!) { (NSModalResponse) in }
  }
  
  @IBAction func addAccount(_ sender: AnyObject)
  {
    addController.resetFields()
    view.window?.beginSheet(addController.window!) { (response) in
      guard response == NSModalResponseOK else { return }
      guard let url = self.addController.location
      else { return }
      
      self.addAccount(type: self.addController.accountType,
                      user: self.addController.userName,
                      password: self.addController.password,
                      location: url as URL)
    }
  }
  
  func addAccount(type: AccountType,
                  user: String,
                  password: String,
                  location: URL)
  {
    var passwordAction = PasswordAction.save
    
    if let oldPassword = XTKeychain.findPassword(url: location, account: user) {
      if oldPassword == password {
        passwordAction = .useExisting
      }
      else {
        let alert = NSAlert()
        
        alert.messageText =
            "There is already a password for that account in the keychain. " +
            "Do you want to change it, or use the existing password?"
        alert.addButton(withTitle: "Change")
        alert.addButton(withTitle: "Use existing")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: view.window!) { (response) in
          switch response {
            case NSAlertFirstButtonReturn:
              self.finishAddAccount(action: .change, type: type, user: user,
                                    password: password, location: location)
            case NSAlertSecondButtonReturn:
              self.finishAddAccount(action: .useExisting, type: type, user: user,
                                    password: "", location: location)
            default:
              break
          }
        }
        return
      }
    }
    finishAddAccount(action: passwordAction, type: type, user: user,
                     password: password, location: location)
  }
  
  func finishAddAccount(action: PasswordAction, type: AccountType,
                        user: String, password: String, location: URL)
  {
    switch action {
      case .save:
        do {
          try XTKeychain.savePassword(url: location, account: user,
                                      password: password)
        }
        catch _ as XTKeychain.Error {
          showError("The password could not be saved because the location field is incorrect.")
          return
        }
        catch _ as NSError {
          showError("The password could not be saved to the Keychain.")
          return
        }
      
      case .change:
        do {
          try XTKeychain.changePassword(url: location,
                                        account: user,
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
  
  @IBAction func removeAccount(_ sender: AnyObject)
  {
    XTAccountsManager.manager.accounts.remove(at: accountsTable.selectedRow)
    accountsTable.reloadData()
  }
}


extension XTAccountsPrefsController: NSTableViewDelegate
{
  func statusImage(forAPI api: XTTeamCityAPI) -> NSImage?
  {
    var imageName: String?
    
    switch api.authenticationStatus {
    case .unknown, .notStarted:
      imageName = NSImageNameStatusNone
    case .inProgress:
      // eventually have a spinner instead
      imageName = NSImageNameStatusPartiallyAvailable
    case .done:
      break
    case .failed:
      imageName = NSImageNameStatusUnavailable
    }
    if let imageName = imageName {
      return NSImage(named: imageName)
    }
    
    switch api.buildTypesStatus {
    case .unknown, .notStarted, .inProgress:
      imageName = NSImageNameStatusAvailable
    case .done:
      imageName = NSImageNameStatusAvailable
    case .failed:
      imageName = NSImageNameStatusPartiallyAvailable
    }
    if let imageName = imageName {
      return NSImage(named: imageName)
    }
    return nil
  }
  
  func tableView(_ tableView: NSTableView,
                 viewFor tableColumn: NSTableColumn?,
                 row: Int) -> NSView?
  {
    guard let tableColumn = tableColumn
      else { return nil }
    
    let view = tableView.make(withIdentifier: tableColumn.identifier,
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
    case "status":
      view.imageView?.isHidden = true
      if account.type == .teamCity {
        guard let api = XTServices.services.teamCityAPI(account)
        else { break }
        
        if let image = statusImage(forAPI: api) {
          view.imageView?.image = image
          view.imageView?.isHidden = false
        }
      }
    default:
      return nil
    }
    return view
  }

}


extension XTAccountsPrefsController: NSTableViewDataSource
{
  func numberOfRows(in tableView: NSTableView) -> Int
  {
    return XTAccountsManager.manager.accounts.count
  }
  
}
