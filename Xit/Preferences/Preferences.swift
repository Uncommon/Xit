import Foundation


enum PreferenceKeys
{
  static let deemphasizeMerges = "deemphasizeMerges"
  static let collapseHistory = "collapseHistory"
  static let resetAmend = "resetAmend"
  static let accounts = "accounts"
  static let statusInTabs = "statusInTabs"
}

extension UserDefaults
{
  @objc dynamic var collapseHistory: Bool
  {
    get { bool(forKey: PreferenceKeys.collapseHistory) }
    set { set(newValue, forKey: PreferenceKeys.collapseHistory) }
  }
  @objc dynamic var deemphasizeMerges: Bool
  {
    get { bool(forKey: PreferenceKeys.deemphasizeMerges) }
    set { set(newValue, forKey: PreferenceKeys.deemphasizeMerges) }
  }
  @objc dynamic var resetAmend: Bool
  {
    get { bool(forKey: PreferenceKeys.resetAmend) }
    set { set(newValue, forKey: PreferenceKeys.resetAmend) }
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
  @objc dynamic var statusInTabs: Bool
  {
    get { bool(forKey: PreferenceKeys.statusInTabs) }
    set { set(newValue, forKey: PreferenceKeys.statusInTabs) }
  }
}
