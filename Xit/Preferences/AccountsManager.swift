import Cocoa


/// Stores information about an account for an online service.
/// Passwords are stored in the keychain. This would have been a `struct` but
/// we need it to be `NSObject` compatible.
class Account: NSObject
{
  var type: AccountType
  var user: String
  var location: URL
  
  init(type: AccountType, user: String, location: URL)
  {
    self.type = type
    self.user = user
    self.location = location
    
    super.init()
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
  /// Account types as stored in preferences
  let userKey = "user"
  let locationKey = "location"
  let typeKey = "type"

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
      if let type = AccountType(name: accountDict[typeKey] as? String),
        let user = accountDict[userKey] as? String,
        let locationString = accountDict[locationKey] as? String,
        let location = URL(string: locationString) {
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
      accountsList.add(accountDict)
    }
    UserDefaults.standard.setValue(accountsList,
                                   forKey: "accounts")
  }
}
