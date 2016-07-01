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
}


struct Account {
  var type: AccountType
  var user: String
  var location: NSURL
}


class XTAccountsPrefsController: NSViewController {
  
  /// Account types as stored in preferences
  let accountTypeNames = ["github", "bitbucket", "teamcity"]
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
    guard let accounts =
        NSUserDefaults.standardUserDefaults().arrayForKey("accounts")
    else { return }
    
    for accountDict in accounts {
      if let type = AccountType(name: accountDict[typeKey]),
         let user = accountDict[userKey],
         let location = NSURL(string: accountDict[locationKey]) {
        accounts.append(Account(type: type, user: user, location: location))
      }
      else {
        NSLog("Couldn't read account: \(accountDict.description)")
      }
    }
  }
  
  func saveAccounts()
  {
    var accountsList = NSMutableArray(capacity: accounts.count)
    
    for account in accounts {
      var accountDict = NSMutableDictionary(capacity: 3)
      
      accountDict[typeKey] = accountTypeNames[account.type.rawValue]
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
      guard let type = AccountType(rawValue: servicePopup.indexOfSelectedItem)
      else { return }
      guard let url = NSURL(string: locationField.stringValue)
      else { return }
      
      addAccount(type,
                 user: userField.stringValue,
                 password: passwordField.stringValue,
                 location: url)
    }
  }
  
  func addAccount(type: AccountType, user: String, password: String, location: NSURL)
  {
    let host = url?.host as NSString
    let path = url.path as NSString
    let accountName = user as NSString
    let password = password as NSString
    
    let err = SecKeychainAddInternetPassword(
        nil,
        host.length, host.UTF8String,
        0, nil,
        accountName.length, accountName.UTF8String,
        path.length, path.UTF8String,
        url.port,
        .HTTP, .HTTPBasic,
        password.length, password.UTF8String,
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
