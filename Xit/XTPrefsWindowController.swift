import Cocoa


class XTPrefsWindowController: NSWindowController
{
  static let sharedPrefsController =
      NSStoryboard(name: NSStoryboard.Name(rawValue: "Preferences"), bundle: nil)
      .instantiateInitialController()!
      as! XTPrefsWindowController
}


protocol PreferencesSaver
{
  func savePreferences()
}
