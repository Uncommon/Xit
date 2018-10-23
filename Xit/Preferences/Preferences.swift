import Foundation


enum PreferenceKeys
{
  static let deemphasizeMerges = "deemphasizeMerges"
  static let collapseHistory = "collapseHistory"
  static let accounts = "accounts"
}

extension UserDefaults
{
  @objc dynamic var collapseHistory: Bool
  {
    get
    {
      return bool(forKey: PreferenceKeys.collapseHistory)
    }
    set
    {
      set(newValue, forKey: PreferenceKeys.collapseHistory)
    }
  }
  @objc dynamic var deemphasizeMerges: Bool
  {
    get
    {
      return bool(forKey: PreferenceKeys.deemphasizeMerges)
    }
    set
    {
      set(newValue, forKey: PreferenceKeys.deemphasizeMerges)
    }
  }
  @objc dynamic var accounts: [Account]
  {
    get
    {
      guard let storedAccounts = array(forKey: PreferenceKeys.accounts)
                                 as? [[String: AnyObject]]
      else { return [] }
      var result: [Account] = []
      
      for accountDict in storedAccounts {
        if let account = Account(dict: accountDict) {
          result.append(account)
        }
        else {
          NSLog("Couldn't read account: \(accountDict.description)")
        }
      }
      return result
    }
    set
    {
      let accountsData = newValue.map { $0.plistDictionary }
      
      setValue(accountsData, forKey: PreferenceKeys.accounts)
    }
  }
}
