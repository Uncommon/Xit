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
            rootView: GeneralPrefsPane(defaults: .xit,
                                       config: GitConfig.default!)
              .padding().fixedSize())
            .sizedToFit(in: size)
        case .accounts:
          return NSHostingController(
            rootView: AccountsPrefsPane(services: .xit,
                                        accountsManager: .xit)
              // Without maxHeight the pane wants to be really tall
              .frame(minWidth: 560, maxHeight: 288)
              .padding())
            .sizedToFit(in: size)
        case .previews:
          return NSHostingController(
            rootView: PreviewsPrefsPane(defaults: .xit)
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
    var tabSize = CGRect.zero

    for tab in Tab.allCases {
      let tabItem = NSTabViewItem(identifier: tab.rawValue)
      let controller = tab.makeController(size: windowFrame.size)

      tabItem.label = tab.label
      tabItem.image = .init(systemSymbolName: tab.imageName)
      tabItem.viewController = controller
      tabController.addTabViewItem(tabItem)
      tabSize = tabSize.union(
          .init(origin: .zero, size: controller.preferredContentSize))
    }

    tabController.selectedTabViewItemIndex = 0
    window!.setContentSize(tabSize.size)
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
