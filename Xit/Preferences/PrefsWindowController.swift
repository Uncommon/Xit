import Cocoa
import SwiftUI


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

  override func windowDidLoad()
  {
    guard let tabController = contentViewController as? NSTabViewController
    else { return }
    let generalItem = NSTabViewItem(identifier: Tab.general.rawValue)
    let generalController = NSHostingController(
      rootView: GeneralPrefsPane(defaults: .standard,
                                 config: GitConfig.default!)
      .padding().fixedSize())

    generalController.preferredContentSize = generalController.sizeThatFits(in: window!.frame.size)
    generalItem.label = "General"
    generalItem.image = .init(systemSymbolName: "gear")
    generalItem.viewController = generalController

    if let oldItem = tabController.tabViewItems.first(
        where: { $0.identifier as? String == Tab.general.rawValue}) {
      tabController.removeTabViewItem(oldItem)
    }
    tabController.insertTabViewItem(generalItem, at: 0)
    tabController.selectedTabViewItemIndex = 0
  }

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
