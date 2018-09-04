import Foundation


enum PreferenceKeys
{
  static let deemphasizeMerges = "deemphasizeMerges"
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
