import Cocoa


enum PasswordAction
{
  case save
  case change
  case useExisting
}


class AccountsPrefsController: NSViewController
{
  // Not a weak reference because there are no other references to it.
  @IBOutlet var addController: AddAccountController!
  @IBOutlet weak var accountsTable: NSTableView!
  @IBOutlet weak var refreshButton: NSButton!
  @IBOutlet weak var editButton: NSButton!
  @IBOutlet weak var deleteButton: NSButton!
  
  var authStatusObserver: NSObjectProtocol?
  
  var selectedAccount: Account?
  {
    let manager = AccountsManager.manager
    guard case let selectedRow = accountsTable.selectedRow,
          selectedRow >= 0,
          selectedRow < manager.accounts.count
    else { return nil }
    
    return manager.accounts[selectedRow]
  }
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    let notificationCenter = NotificationCenter.default
    
    AccountsManager.manager.readAccounts()
    authStatusObserver = notificationCenter.addObserver(
        forName: .authenticationStatusChanged,
        object: nil,
        queue: OperationQueue.main) {
      [weak self] (_) in
      self?.accountsTable.reloadData()
    }
    editButton.image = NSImage(systemSymbolName: "pencil")!
      // the regular pencil icon is very thin
      .withSymbolConfiguration(.init(pointSize: 9, weight: .black))
    updateActionButtons()
  }
  
  func updateActionButtons()
  {
    let enabled = accountsTable.selectedRow != -1
    
    deleteButton.isEnabled = enabled
    refreshButton.isEnabled = enabled
    editButton.isEnabled = enabled
  }
  
  func showError(_ message: String)
  {
    let alert = NSAlert()
    
    alert.messageText = message
    alert.beginSheetModal(for: view.window!) { (_) in }
  }
  
  @IBAction
  func addAccount(_ sender: AnyObject)
  {
    addController.resetForAdd()
    view.window?.beginSheet(addController.window!,
                            completionHandler: addAccountDone)
  }
  
  @IBAction
  func editAccount(_ sender: Any)
  {
    guard let account = selectedAccount
    else { return }
    
    addController.loadFieldsForEdit(from: account)
    view.window?.beginSheet(addController.window!,
                            completionHandler: editAccountDone)
  }

  func addAccountDone(response: NSApplication.ModalResponse)
  {
    guard response == NSApplication.ModalResponse.OK,
          let url = addController.location
    else { return }
    
    addAccount(type: addController.accountType,
               user: addController.userName,
               password: addController.password,
               location: url as URL)
    updateActionButtons()
    savePreferences()
  }
  
  func editAccountDone(response: NSApplication.ModalResponse)
  {
    guard response == NSApplication.ModalResponse.OK,
          let account = selectedAccount
    else { return }
    let oldUser = account.user
    let newUser = addController.userName
    let oldURL = account.location
    let newURL = addController.location!  // addController does validation
    let oldPassword = XTKeychain.shared.find(url: oldURL, account: oldUser)
    let newPassword = addController.password

    if oldPassword != newPassword || oldUser != newUser || oldURL != newURL {
      do {
        let newAccount = Account(type: account.type,
                                 user: newUser,
                                 location: newURL)
        
        try AccountsManager.manager.modify(oldAccount: account,
                                           newAccount: newAccount,
                                           newPassword: newPassword)
      }
      catch let error as NSError where error.code == errSecUserCanceled {
        return
      }
      catch PasswordError.invalidURL {
        NSAlert.showMessage(window: view.window!, message: .keychainInvalidURL)
      }
      catch let error {
        print("changePassword failure: \(error)")
        NSAlert.showMessage(window: view.window!, message: .keychainError)
      }
    }

    account.user = newUser
    account.location = newURL
    
    // notify the service

    let columns = 0..<accountsTable.numberOfColumns
    
    accountsTable.reloadData(forRowIndexes: [accountsTable.selectedRow],
                             columnIndexes: IndexSet(integersIn: columns))
    savePreferences()
  }
  
  func addAccount(type: AccountType,
                  user: String,
                  password: String,
                  location: URL)
  {
    let account = Account(type: type, user: user, location: location)
    
    do {
      try AccountsManager.manager.add(account, password: password)
      accountsTable.reloadData()
    }
    catch let error as PasswordError {
      let errorString: UIString
      
      switch error {
        case .invalidName:
          errorString = .invalidName
        case .invalidURL:
          errorString = .invalidURL
        default:
          errorString = .unexpectedError
      }
      NSAlert.showMessage(window: view.window!,
                          message: .cantSavePassword,
                          infoString: errorString)
    }
    catch let error as NSError {
      NSAlert.showMessage(window: view.window!,
                          message: .cantSavePassword,
                          infoString: UIString(error: error))
    }
  }
  
  @IBAction
  func removeAccount(_ sender: AnyObject)
  {
    guard let window = view.window
    else { return }
    let alert = NSAlert()
    
    alert.messageString = .confirmDeleteAccount
    alert.addButton(withString: .delete)
    alert.addButton(withString: .cancel)
    // Cancel should be default for destructive actions
    alert.buttons[0].keyEquivalent = "D"
    alert.buttons[1].keyEquivalent = "\r"
    
    alert.beginSheetModal(for: window) {
      (response) in
      guard response == NSApplication.ModalResponse.alertFirstButtonReturn
      else { return }
      
      AccountsManager.manager.accounts.remove(at: self.accountsTable.selectedRow)
      self.accountsTable.reloadData()
      self.updateActionButtons()
    }
  }
  
  @IBAction
  func refreshAccount(_ sender: Any)
  {
    guard let account = selectedAccount
    else { return }
    
    switch account.type {
      
      case .teamCity:
        Services.shared.teamCityAPI(account)?.attemptAuthentication()
      
      case .bitbucketServer:
        Services.shared.bitbucketServerAPI(account)?.attemptAuthentication()
      
      default:
        break
    }
  }
}

extension AccountsPrefsController: PreferencesSaver
{
  func savePreferences()
  {
    AccountsManager.manager.saveAccounts()
  }
}


extension AccountsPrefsController: NSTableViewDelegate
{
  enum ColumnID
  {
    static let service = ¶"service"
    static let userName = ¶"userName"
    static let location = ¶"location"
    static let status = ¶"status"
  }
  
  func statusImage(forTeamCity api: TeamCityAPI?) -> NSImage?
  {
    guard let api = api
    else { return NSImage(named: NSImage.statusUnavailableName) }
    var imageName: NSImage.Name?
    
    switch api.authenticationStatus {
      case .unknown, .notStarted:
        imageName = NSImage.statusNoneName
      case .inProgress:
        // eventually have a spinner instead
        imageName = NSImage.statusPartiallyAvailableName
      case .done:
        break
      case .failed:
        imageName = NSImage.statusUnavailableName
    }
    if let imageName = imageName {
      return NSImage(named: imageName)
    }
    
    switch api.buildTypesStatus {
      case .unknown, .notStarted, .inProgress:
        imageName = NSImage.statusAvailableName
      case .done:
        imageName = NSImage.statusAvailableName
      case .failed:
        imageName = NSImage.statusPartiallyAvailableName
    }
    if let imageName = imageName {
      return NSImage(named: imageName)
    }
    return nil
  }
  
  func statusImage(forBitbucket api: BitbucketServerAPI?) -> NSImage?
  {
    guard let api = api
    else { return NSImage(named: NSImage.statusUnavailableName) }
    let imageName: NSImage.Name
    
    switch api.authenticationStatus {
      case .unknown, .notStarted:
        imageName = NSImage.statusNoneName
      case .inProgress:
        // eventually have a spinner instead
        imageName = NSImage.statusPartiallyAvailableName
      case .done:
        imageName = NSImage.statusAvailableName
      case .failed:
        imageName = NSImage.statusUnavailableName
    }
    return NSImage(named: imageName)
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
    let account = AccountsManager.manager.accounts[row]
    
    switch tableColumn.identifier {
      case ColumnID.service:
        view.textField?.uiStringValue = account.type.displayName
        view.imageView?.image = NSImage(named: account.type.imageName)
      case ColumnID.userName:
        view.textField?.stringValue = account.user
      case ColumnID.location:
        view.textField?.stringValue = account.location.absoluteString
      case ColumnID.status:
        view.imageView?.isHidden = true
        switch account.type {
          case .teamCity:
            let api = Services.shared.teamCityAPI(account)
            
            if let image = statusImage(forTeamCity: api) {
              view.imageView?.image = image
              view.imageView?.isHidden = false
            }
          case .bitbucketServer:
            let api = Services.shared.bitbucketServerAPI(account)
            
            if let image = statusImage(forBitbucket: api) {
              view.imageView?.image = image
              view.imageView?.isHidden = false
            }
          default:
            break
        }
      default:
        return nil
    }
    return view
  }
  
  func tableViewSelectionDidChange(_ notification: Notification)
  {
    updateActionButtons()
  }
}


extension AccountsPrefsController: NSTableViewDataSource
{
  func numberOfRows(in tableView: NSTableView) -> Int
  {
    return AccountsManager.manager.accounts.count
  }
}
