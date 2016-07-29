import Cocoa


enum PasswordAction {
  case Save
  case Change
  case UseExisting
}


class XTAccountsPrefsController: NSViewController, PreferencesSaver {
  
  // Not a weak reference because there are no other references to it.
  @IBOutlet var addController: XTAddAccountController!
  @IBOutlet weak var accountsTable: NSTableView!
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    let notificationCenter = NSNotificationCenter.defaultCenter()
    
    XTAccountsManager.manager.readAccounts()
    notificationCenter.addObserverForName(
        XTBasicAuthService.AuthenticationStatusChangedNotification,
        object: nil,
        queue: NSOperationQueue.mainQueue()) { (_) in
      self.accountsTable.reloadData()
    }
    notificationCenter.addObserverForName(
        NSWindowDidResignKeyNotification,
        object: self.view.window,
        queue: nil) { (_) in
      self.savePreferences()
    }
  }
  
  deinit
  {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }
  
  func savePreferences()
  {
    XTAccountsManager.manager.saveAccounts()
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
  
  func addAccount(type: AccountType,
                  user: String,
                  password: String,
                  location: NSURL)
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
}


extension XTAccountsPrefsController: NSTableViewDelegate {
  
  func statusImage(forAPI api: XTTeamCityAPI) -> NSImage?
  {
    var imageName: String?
    
    switch api.authenticationStatus {
    case .Unknown, .NotStarted:
      imageName = NSImageNameStatusNone
    case .InProgress:
      // eventually have a spinner instead
      imageName = NSImageNameStatusPartiallyAvailable
    case .Done:
      break
    case .Failed:
      imageName = NSImageNameStatusUnavailable
    }
    if let imageName = imageName {
      return NSImage(named: imageName)
    }
    
    switch api.buildTypesStatus {
    case .Unknown, .NotStarted, .InProgress:
      imageName = NSImageNameStatusAvailable
    case .Done:
      imageName = NSImageNameStatusAvailable
    case .Failed:
      imageName = NSImageNameStatusPartiallyAvailable
    }
    if let imageName = imageName {
      return NSImage(named: imageName)
    }
    return nil
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
    case "status":
      view.imageView?.hidden = true
      if account.type == .TeamCity {
        guard let api = XTServices.services.teamCityAPI(account)
        else { break }
        
        if let image = statusImage(forAPI: api) {
          view.imageView?.image = image
          view.imageView?.hidden = false
        }
      }
    default:
      return nil
    }
    return view
  }

}


extension XTAccountsPrefsController: NSTableViewDataSource {
  
  func numberOfRowsInTableView(tableView: NSTableView) -> Int
  {
    return XTAccountsManager.manager.accounts.count
  }
  
}