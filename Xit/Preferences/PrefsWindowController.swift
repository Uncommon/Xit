import Cocoa
import SwiftUI


final class PrefsWindowController: NSWindowController
{
  enum Tab: String, CaseIterable
  {
    case general
    case accounts
    case previews

    var label: String
    {
      switch self {
        case .general:  return "General"
        case .accounts: return "Accounts"
        case .previews: return "Previews"
      }
    }

    var imageName: String
    {
      switch self {
        case .general:  return "gear"
        case .accounts: return "person.crop.circle"
        case .previews: return "doc.text"
      }
    }

    func makeController(size: CGSize) -> NSViewController
    {
      switch self {
        case .general:
          return NSHostingController(
            rootView: GeneralPrefsPane(defaults: .standard,
                                       config: GitConfig.default!)
              .padding().fixedSize())
            .sizedToFit(in: size)
        case .accounts:
          return NSHostingController(
            rootView: AccountsPrefsPane(services: .shared,
                                        accountsManager: .manager)
              .padding().frame(minHeight: 300.0))
            .sizedToFit(in: size)
        case .previews:
          return NSHostingController(
            rootView: PreviewsPrefsPane(defaults: .standard)
              .padding().fixedSize())
            .sizedToFit(in: size)
      }
    }
  }
  
  static let shared =
      NSStoryboard(name: "Preferences", bundle: nil)
      .instantiateInitialController()!
      as! PrefsWindowController
  
  var tabController: NSTabViewController!

  override func windowDidLoad()
  {
    guard let tabController = contentViewController as? NSTabViewController
    else {
      assertionFailure("no tab controller")
      return
    }
    let windowFrame = window!.frame

    for tab in Tab.allCases {
      let tabItem = NSTabViewItem(identifier: tab.rawValue)

      tabItem.label = tab.label
      tabItem.image = .init(systemSymbolName: tab.imageName)
      tabItem.viewController = tab.makeController(size: windowFrame.size)
      tabController.addTabViewItem(tabItem)
    }

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

extension NSHostingController
{
  func sizedToFit(in size: CGSize) -> Self
  {
    preferredContentSize = sizeThatFits(in: size)
    return self
  }
}
