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

  static let diffWhitespace = PreferenceKey("diffWhitespace",
                                            WhitespaceSetting.showAll)
  static let tabWidth = PreferenceKey("tabWidth", 4)
  static let contextLines = PreferenceKey("contextLines", 3)
  static let fontName = PreferenceKey("fontName", "Menlo-Regular")
  static let fontSize = PreferenceKey("fontSize", 11)
  static let wrapping = PreferenceKey("wrapping", TextWrapping.none)
  static let guideWidth = PreferenceKey("guideWidth", 83)
  static let showGuide = PreferenceKey("showGuide", true)
}

struct PreferenceKey<T>
{
  let key: String
  let defaultValue: T

  init(_ key: String, _ value: T)
  {
    self.key = key
    self.defaultValue = value
  }
}

extension PreferenceKey: Sendable where T: Sendable {}

extension WhitespaceSetting
{
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
  static var xit: UserDefaults
  {
    #if DEBUG
    switch Testing.defaults {
      case .standard:
        return .standard
      default:
        return .testing
    }
    #else
    return .standard
    #endif
  }

  nonisolated(unsafe) // only in previews and initialization
  static var testing: UserDefaults = {
    let result = UserDefaults(suiteName: "xit-testing")!
    result.removePersistentDomain(forName: "xit-testing")
    return result
  }()

  subscript<T>(_ key: PreferenceKey<T>) -> T
  {
    get { value(forKey: key.key) as? T ?? key.defaultValue }
    set { setValue(newValue, forKey: key.key) }
  }
  subscript<T>(_ key: PreferenceKey<T>) -> T where T: RawRepresentable
  {
    get
    {
      (object(forKey: key.key) as? T.RawValue)
          .flatMap { .init(rawValue: $0) } ?? key.defaultValue
    }
    set { setValue(newValue.rawValue, forKey: key.key) }
  }

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
  var accounts: [Account]
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
          serviceLogger.debug("Couldn't read account: \(accountDict.description)")
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
    get { self[PreferenceKeys.fontName] }
    set { self[PreferenceKeys.fontName] = newValue }
  }
  @objc dynamic var fontSize: Int
  {
    get { self[PreferenceKeys.fontSize] }
    set { self[PreferenceKeys.fontSize] = newValue }
  }
  @objc dynamic var tabWidth: Int
  {
    get { self[PreferenceKeys.tabWidth] }
    set { self[PreferenceKeys.tabWidth] = newValue }
  }
  @objc dynamic var contextLines: Int
  {
    get { self[PreferenceKeys.contextLines] }
    set { self[PreferenceKeys.contextLines] = newValue }
  }
  @objc dynamic var guideWidth: Int
  {
    get { self[PreferenceKeys.guideWidth] }
    set { self[PreferenceKeys.guideWidth] = newValue }
  }
  @objc dynamic var showGuide: Bool
  {
    get { self[PreferenceKeys.showGuide] }
    set { self[PreferenceKeys.showGuide] = newValue }
  }
  dynamic var wrapping: TextWrapping
  {
    get { self[PreferenceKeys.wrapping] }
    set { self[PreferenceKeys.wrapping] = newValue }
  }
  dynamic var whitespace: WhitespaceSetting
  {
    get { self[PreferenceKeys.diffWhitespace] }
    set { self[PreferenceKeys.diffWhitespace] = newValue }
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
