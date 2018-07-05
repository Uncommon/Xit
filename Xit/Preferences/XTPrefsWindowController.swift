import Cocoa


class XTPrefsWindowController: NSWindowController
{
  static let sharedPrefsController =
      NSStoryboard(name: ◊"Preferences", bundle: nil)
      .instantiateInitialController()!
      as! XTPrefsWindowController
}


protocol PreferencesSaver
{
  func savePreferences()
}
