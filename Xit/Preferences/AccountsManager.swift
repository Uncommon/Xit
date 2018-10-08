import Cocoa


/// Stores information about an account for an online service.
/// Passwords are stored in the keychain. This would have been a `struct` but
/// we need it to be `NSObject` compatible.
class Account: NSObject
{
  var type: AccountType
  var user: String
  var location: URL
  
  /// Account fields as stored in preferences
  enum Keys
  {
    static let user = "user"
    static let location = "location"
    static let type = "type"
  }
  
  var plistDictionary: NSDictionary
  {
    let accountDict = NSMutableDictionary(capacity: 3)
    
    accountDict[Account.Keys.type] = type.name
    accountDict[Account.Keys.user] = user
    accountDict[Account.Keys.location] = location.absoluteString
    return accountDict
  }

  init(type: AccountType, user: String, location: URL)
  {
    self.type = type
    self.user = user
    self.location = location
    
    super.init()
  }
  
  convenience init?(dict: [String: AnyObject])
  {
    guard let type = AccountType(name: dict[Keys.type] as? String),
          let user = dict[Keys.user] as? String,
          let location = dict[Keys.location] as? String,
          let url = URL(string: location)
    else { return nil }
    
    self.init(type: type, user: user, location: url)
  }
}

func == (left: Account, right: Account) -> Bool
{
  return (left.type == right.type) &&
         (left.user == right.user) &&
         (left.location.absoluteString == right.location.absoluteString)
}


class AccountsManager: NSObject
{
  static let manager = AccountsManager()
  
  var accounts: [Account] = []
  
  override init()
  {
    super.init()
    
    readAccounts()
  }
  
  func accounts(ofType type: AccountType) -> [Account]
  {
    return accounts.filter { $0.type == type }
  }
  
  func add(_ account: Account)
  {
    accounts.append(account)
  }
  
  func readAccounts()
  {
    guard let storedAccounts =
      UserDefaults.standard.array(forKey: "accounts")
        as? [[String: AnyObject]]
    else { return }
    
    accounts.removeAll()
    for accountDict in storedAccounts {
      if let account = Account(dict: accountDict) {
        accounts.append(account)
      }
      else {
        NSLog("Couldn't read account: \(accountDict.description)")
      }
    }
  }
  
  func saveAccounts()
  {
    let accountsData = accounts.map { $0.plistDictionary }
    
    UserDefaults.standard.setValue(accountsData,
                                   forKey: "accounts")
  }
}
