import Cocoa


enum PasswordAction
{
  case save
  case change
  case useExisting
}


class XTAccountsPrefsController: NSViewController
{
  // Not a weak reference because there are no other references to it.
  @IBOutlet var addController: XTAddAccountController!
  @IBOutlet weak var accountsTable: NSTableView!
  @IBOutlet weak var refreshButton: NSButton!
  
  var authStatusObserver: NSObjectProtocol?
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    let notificationCenter = NotificationCenter.default
    
    XTAccountsManager.manager.readAccounts()
    authStatusObserver = notificationCenter.addObserver(
        forName: NSNotification.Name(rawValue:
            BasicAuthService.AuthenticationStatusChangedNotification),
        object: nil,
        queue: OperationQueue.main) {
      [weak self] (_) in
      self?.accountsTable.reloadData()
    }
    updateRefreshButton()
  }
  
  deinit
  {
    let center = NotificationCenter.default
    
    authStatusObserver.map { center.removeObserver($0) }
  }
  
  func updateRefreshButton()
  {
    refreshButton.isEnabled = accountsTable.selectedRow != -1
  }
  
  func showError(_ message: String)
  {
    let alert = NSAlert()
    
    alert.messageText = message
    alert.beginSheetModal(for: view.window!) { (_) in }
  }
  
  @IBAction func addAccount(_ sender: AnyObject)
  {
    addController.resetFields()
    view.window?.beginSheet(addController.window!) { (response) in
      guard response == NSApplication.ModalResponse.OK
      else { return }
      guard let url = self.addController.location
      else { return }
      
      self.addAccount(type: self.addController.accountType,
                      user: self.addController.userName,
                      password: self.addController.password,
                      location: url as URL)
      self.updateRefreshButton()
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
        alert.beginSheetModal(for: view.window!) {
          (response) in
          switch response {
            case NSApplication.ModalResponse.alertFirstButtonReturn:
              self.finishAddAccount(action: .change, type: type, user: user,
                                    password: password, location: location)
            case NSApplication.ModalResponse.alertSecondButtonReturn:
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
          showError("The password could not be saved because the location " +
                    "field is incorrect.")
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
    updateRefreshButton()
  }
  
  @IBAction func refreshAccount(_ sender: Any)
  {
    let manager = XTAccountsManager.manager
    let selectedRow = accountsTable.selectedRow
    guard selectedRow >= 0 && selectedRow < manager.accounts.count
    else { return }
    let account = manager.accounts[selectedRow]
    
    switch account.type {
      
      case .teamCity:
        guard let api = Services.shared.teamCityAPI(account)
        else { break }
      
        api.attemptAuthentication()
      
      default:
        break
    }
  }
}

extension XTAccountsPrefsController: PreferencesSaver
{
  func savePreferences()
  {
    XTAccountsManager.manager.saveAccounts()
  }
}


extension XTAccountsPrefsController: NSTableViewDelegate
{
  struct ColumnID
  {
    static let service = ¶"service"
    static let userName = ¶"userName"
    static let location = ¶"location"
    static let status = ¶"status"
  }
  
  func statusImage(forAPI api: TeamCityAPI) -> NSImage?
  {
    var imageName: NSImage.Name?
    
    switch api.authenticationStatus {
      case .unknown, .notStarted:
        imageName = .statusNone
      case .inProgress:
        // eventually have a spinner instead
        imageName = .statusPartiallyAvailable
      case .done:
        break
      case .failed:
        imageName = .statusUnavailable
    }
    if let imageName = imageName {
      return NSImage(named: imageName)
    }
    
    switch api.buildTypesStatus {
      case .unknown, .notStarted, .inProgress:
        imageName = .statusAvailable
      case .done:
        imageName = .statusAvailable
      case .failed:
        imageName = .statusPartiallyAvailable
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
    
    let view = tableView.makeView(withIdentifier: tableColumn.identifier,
                              owner: self)
               as! NSTableCellView
    let account = XTAccountsManager.manager.accounts[row]
    
    switch tableColumn.identifier {
      case ColumnID.service:
        view.textField?.stringValue = account.type.displayName
        view.imageView?.image = NSImage(named: account.type.imageName)
      case ColumnID.userName:
        view.textField?.stringValue = account.user
      case ColumnID.location:
        view.textField?.stringValue = account.location.absoluteString
      case ColumnID.status:
        view.imageView?.isHidden = true
        if account.type == .teamCity {
          guard let api = Services.shared.teamCityAPI(account)
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
  
  func tableViewSelectionDidChange(_ notification: Notification)
  {
    updateRefreshButton()
  }
}


extension XTAccountsPrefsController: NSTableViewDataSource
{
  func numberOfRows(in tableView: NSTableView) -> Int
  {
    return XTAccountsManager.manager.accounts.count
  }
}
