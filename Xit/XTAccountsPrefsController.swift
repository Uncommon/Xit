import Cocoa


enum AccountType : Int {
  case GitHub = 0
  case BitBucket = 1
  case TeamCity = 2
  
  init?(name: String?)
  {
    guard name != nil else { return nil }
    
    switch name! {
    case "github":
      self = .GitHub
    case "bitbucket":
      self = .BitBucket
    case "teamcity":
      self = .TeamCity
    default:
      return nil
    }
  }
  
  var name: String
  {
    switch self {
      case .GitHub: return "github"
      case .BitBucket: return "bitbucket"
      case .TeamCity: return "teamcity"
    }
  }
  
  var displayName: String
  {
    switch self {
    case .GitHub: return "GitHub"
    case .BitBucket: return "BitBucket"
    case .TeamCity: return "TeamCity"
    }
  }
  
  var defaultLocation: String
  {
    switch self {
      case .GitHub: return "https://api.github.com"
      case .BitBucket: return "https://api.bitbucket.org"
      case .TeamCity: return ""
    }
  }
  
  var imageName: String
  {
    switch self {
      case .GitHub: return "githubTemplate"
      case .BitBucket: return "bitbucketTemplate"
      case .TeamCity: return "teamcityTemplate"
    }
  }
}


enum PasswordAction {
  case Save
  case Change
  case UseExisting
}


struct Account {
  var type: AccountType
  var user: String
  var location: NSURL
}


class XTAccountsPrefsController: NSViewController {
  
  /// Account types as stored in preferences
  let userKey = "user"
  let locationKey = "location"
  let typeKey = "type"
  
  var accounts: [Account] = []
  
  @IBOutlet weak var addController: XTAddAccountController!
  @IBOutlet weak var accountsTable: NSTableView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    readAccounts()
  }
  
  func showError(message: String)
  {
    let alert = NSAlert()
    
    alert.messageText = message
    alert.beginSheetModalForWindow(view.window!) { (NSModalResponse) in }
  }
  
  func readAccounts()
  {
    guard let storedAccounts =
        NSUserDefaults.standardUserDefaults().arrayForKey("accounts")
        as? [[String: AnyObject]]
    else { return }
    
    for accountDict in storedAccounts {
      if let type = AccountType(name: accountDict[typeKey] as? String),
         let user = accountDict[userKey] as? String,
         let locationString = accountDict[locationKey] as? String,
         let location = NSURL(string: locationString) {
        accounts.append(Account(type: type, user: user, location: location))
      }
      else {
        NSLog("Couldn't read account: \(accountDict.description)")
      }
    }
  }
  
  func saveAccounts()
  {
    let accountsList = NSMutableArray(capacity: accounts.count)
    
    for account in accounts {
      let accountDict = NSMutableDictionary(capacity: 3)
      
      accountDict[typeKey] = account.type.name
      accountDict[userKey] = account.user
      accountDict[locationKey] = account.location.absoluteString
      accountsList.addObject(accountDict)
    }
    NSUserDefaults.standardUserDefaults().setValue(accountsList,
                                                   forKey: "accounts")
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
    
    accounts.append(Account(type: type,
                            user: user,
                            location: location))
    accountsTable.reloadData()
  }
  
  @IBAction func removeAccount(sender: AnyObject)
  {
    accounts.removeAtIndex(accountsTable.selectedRow)
    accountsTable.reloadData()
  }
  
  func numberOfRowsInTableView(tableView: NSTableView) -> Int
  {
    return accounts.count
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
    let account = accounts[row]
    
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
