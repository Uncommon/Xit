import Foundation


enum PreferenceKeys
{
  static let deemphasizeMerges = "deemphasizeMerges"
  static let collapseHistory = "collapseHistory"
  static let resetAmend = "resetAmend"
  static let fetchTags = "FetchTags"
  static let accounts = "accounts"
  static let statusInTabs = "statusInTabs"
  static let stripComments = "stripComments"
  static let showColumns = "showColumns"

  static let diffWhitespace = "diffWhitespace"
  static let tabWidth = "tabWidth"
  static let contextLines = "contextLines"
  static let fontName = "fontName"
  static let fontSize = "fontSize"
  static let wrapping = "wrapping"
}

enum WhitespaceSetting: String, CaseIterable
{
  case showAll
  case ignoreEOL
  case ignoreAll

  var displayName: String
  {
    switch self {
      case .showAll: return "Show whitespace changes"
      case .ignoreEOL: return "Ignore end of line whitespace"
      case .ignoreAll: return "Ignore all whitespace"
    }
  }
}

extension UserDefaults
{
  static var testing: UserDefaults = {
    let result = UserDefaults(suiteName: "xit-testing")!
    result.removePersistentDomain(forName: "xit-testing")
    return result
  }()

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
  @objc dynamic var stripComments: Bool
  {
    get { bool(forKey: PreferenceKeys.stripComments) }
    set { set(newValue, forKey: PreferenceKeys.stripComments) }
  }
  @objc dynamic var showColumns: [String]
  {
    get { value(forKey: PreferenceKeys.showColumns) as? [String] ?? [] }
    set { set(newValue, forKey: PreferenceKeys.showColumns) }
  }
  @objc dynamic var fontName: String
  {
    get { object(forKey: PreferenceKeys.fontName) as? String ?? "Menlo-Regular" }
    set { set(newValue, forKey: PreferenceKeys.fontName) }
  }
  @objc dynamic var fontSize: Int
  {
    get { object(forKey: PreferenceKeys.fontSize) as? Int ?? 11 }
    set { set(newValue, forKey: PreferenceKeys.fontSize) }
  }
  @objc dynamic var tabWidth: Int
  {
    get { object(forKey: PreferenceKeys.tabWidth) as? Int ?? 4 }
    set { set(newValue, forKey: PreferenceKeys.tabWidth) }
  }
  @objc dynamic var contextLines: Int
  {
    get { object(forKey: PreferenceKeys.contextLines) as? Int ?? 3 }
    set { set(newValue, forKey: PreferenceKeys.contextLines) }
  }
  dynamic var wrapping: TextWrapping
  {
    get
    {
      (object(forKey: PreferenceKeys.wrapping) as? Int).flatMap {
        .init(rawValue: $0)
      } ?? .none
    }
    set { set(newValue.rawValue, forKey: PreferenceKeys.wrapping) }
  }
  dynamic var whitespace: WhitespaceSetting
  {
    get
    {
      (object(forKey: PreferenceKeys.diffWhitespace) as? String).flatMap {
        .init(rawValue: $0)
      } ?? .showAll
    }
    set { set(newValue.rawValue, forKey: PreferenceKeys.contextLines) }
  }

  func setShowColumn(_ identifier: String, show: Bool)
  {
    if show {
      showColumns += [identifier]
    }
    else {
      showColumns = showColumns.filter { $0 != identifier }
    }
  }
}
