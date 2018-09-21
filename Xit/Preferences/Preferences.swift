import Foundation


enum PreferenceKeys
{
  static let deemphasizeMerges = "deemphasizeMerges"
  static let collapseHistory = "collapseHistory"
}


enum Preferences
{
  static var deemphasizeMerges: Bool
  {
    get
    {
      return UserDefaults.standard.bool(forKey: PreferenceKeys.deemphasizeMerges)
    }
    set
    {
      return UserDefaults.standard.set(newValue,
                                       forKey: PreferenceKeys.deemphasizeMerges)
    }
  }
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
}
