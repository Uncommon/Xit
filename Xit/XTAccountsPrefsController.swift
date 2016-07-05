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
  
  @IBOutlet weak var accountsTable: NSTableView!
  @IBOutlet weak var addSheet: NSWindow!
  
  @IBOutlet weak var servicePopup: NSPopUpButton!
  @IBOutlet weak var userField: NSTextField!
  @IBOutlet weak var passwordField: NSSecureTextField!
  @IBOutlet weak var locationField: NSTextField!
  
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
    view.window?.beginSheet(addSheet) { (response) in
      guard response == NSModalResponseOK else { return }
      guard let type = AccountType(rawValue: self.servicePopup.indexOfSelectedItem)
      else { return }
      guard let url = NSURL(string: self.locationField.stringValue)
      else { return }
      
      self.addAccount(type,
                      user: self.userField.stringValue,
                      password: self.passwordField.stringValue,
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
  
  @IBAction func typeChanged(sender: AnyObject)
  {
    locationField.stringValue = XTAccountsPrefsController.defaultLocation(
        AccountType(rawValue: servicePopup.indexOfSelectedItem)!)
  }
  
  @IBAction func acceptAdd(sender: AnyObject)
  {
    view.window?.endSheet(addSheet, returnCode: NSModalResponseOK)
  }
  
  @IBAction func cancelAdd(sender: AnyObject)
  {
    view.window?.endSheet(addSheet, returnCode: NSModalResponseCancel)
  }
  
  class func defaultLocation(type: AccountType) -> String
  {
    switch type {
      case .GitHub:
        return "api.github.com"
      case .BitBucket:
        return "api.bitbucket.org"
      case .TeamCity:
        return ""
    }
  }
}
