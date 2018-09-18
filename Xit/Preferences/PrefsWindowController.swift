import Cocoa


class PrefsWindowController: NSWindowController
{
  static let sharedPrefsController =
      NSStoryboard(name: "Preferences", bundle: nil)
      .instantiateInitialController()!
      as! PrefsWindowController
}


protocol PreferencesSaver
{
  func savePreferences()
}
