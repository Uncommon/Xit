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
  
  var defaultLocation: String
  {
    switch self {
      case .GitHub: return "https://api.github.com"
      case .BitBucket: return "https://api.bitbucket.org"
      case .TeamCity: return ""
    }
  }
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
    let host = location.host! as NSString
    let path = location.path! as NSString
    let accountName = user as NSString
    let password = password as NSString
    let port: UInt16 = location.port?.unsignedShortValue ?? 80
    
    let err = SecKeychainAddInternetPassword(
        nil,
        UInt32(host.length), host.UTF8String,
        0, nil,
        UInt32(accountName.length), accountName.UTF8String,
        UInt32(path.length), path.UTF8String,
        port,
        .HTTP, .HTTPBasic,
        UInt32(password.length), password.UTF8String,
        nil)
    
    guard err == noErr else {
      // alert
      return
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
}
