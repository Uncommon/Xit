import Cocoa


/// Stores information about an account for an online service.
/// Passwords are stored in the keychain.
/// This would have been a `struct` but we need it to be `NSObject` compatible.
final class Account: NSObject
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
    
    accountDict[Keys.type] = type.name
    accountDict[Keys.user] = user
    accountDict[Keys.location] = location.absoluteString
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
  
  override func isEqual(_ object: Any?) -> Bool
  {
    if let other = object as? Account {
      return self == other
    }
    return false
  }
}

func == (left: Account, right: Account) -> Bool
{
  return (left.type == right.type) &&
         (left.user == right.user) &&
         (left.location.absoluteString == right.location.absoluteString)
}


final class AccountsManager: NSObject
{
  static let manager = AccountsManager()
  
  let defaults: UserDefaults
  let passwordStorage: any PasswordStorage
  
  var accounts: [Account] = []
  
  init(defaults: UserDefaults? = nil,
       passwordStorage: (any PasswordStorage)? = nil)
  {
    self.defaults = defaults ?? .standard
    self.passwordStorage = passwordStorage ?? XTKeychain.shared
    super.init()
    
    readAccounts()
  }
  
  func accounts(ofType type: AccountType) -> [Account]
  {
    return accounts.filter { $0.type == type }
  }
  
  func add(_ account: Account, password: String) throws
  {
    if let existingPassword = passwordStorage.find(url: account.location,
                                                   account: account.user) {
      if existingPassword != password {
        try passwordStorage.change(url: account.location, newURL: nil,
                                   account: account.user, newAccount: nil,
                                   password: password)
      }
    }
    else {
      try passwordStorage.save(url: account.location, account: account.user,
                               password: password)
    }
    accounts.append(account)
  }
  
  func delete(account: Account)
  {
    if let index = accounts.firstIndex(where: { $0 == account }) {
      accounts.remove(at: index)
    }
  }
  
  func modify(oldAccount: Account,
              newAccount: Account, newPassword: String?) throws
  {
    guard let index = accounts.firstIndex(where: { $0 == oldAccount })
    else { throw PasswordError.itemNotFound }
    let oldPassword = passwordStorage.find(url: oldAccount.location,
                                           account: oldAccount.user)
    let changePassword = newPassword != nil && newPassword != oldPassword
    
    if newAccount != oldAccount || changePassword {
      if let password = oldPassword {
        try passwordStorage.change(url: oldAccount.location,
                                   newURL: newAccount.location,
                                   account: oldAccount.user,
                                   newAccount: newAccount.user,
                                   password: newPassword ?? password)
      }
      else if let password = newPassword {
        try passwordStorage.save(url: newAccount.location,
                                 account: newAccount.user,
                                 password: password)
      }
      else {
        throw PasswordError.passwordNotSpecified
      }
    }
    accounts[index] = newAccount
  }
  
  func readAccounts()
  {
    accounts = defaults.accounts
  }
  
  func saveAccounts()
  {
    defaults.accounts = accounts
  }
}
