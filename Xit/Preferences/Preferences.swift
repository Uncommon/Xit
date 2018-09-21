import Foundation


enum PreferenceKeys
{
  static let deemphasizeMerges = "deemphasizeMerges"
  static let collapseHistory = "collapseHistory"
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
