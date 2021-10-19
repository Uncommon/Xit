import Cocoa


final class PrefsWindowController: NSWindowController
{
  enum Tab: String
  {
    case general
    case accounts
    case previews
  }
  
  static let shared =
      NSStoryboard(name: "Preferences", bundle: nil)
      .instantiateInitialController()!
      as! PrefsWindowController
  
  var tabController: NSTabViewController!
  
  static func show(tab: Tab)
  {
    shared.window?.makeKeyAndOrderFront(nil)
    
    guard let tabController = shared.window?.contentViewController
                              as? NSTabViewController
    else { return }
    
    tabController.tabView.selectTabViewItem(withIdentifier: tab.rawValue)
  }
}


protocol PreferencesSaver
{
  func savePreferences()
}
