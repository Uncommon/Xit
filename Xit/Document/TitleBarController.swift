import Cocoa
import Combine
import XitGit

@MainActor
protocol TitleBarDelegate: AnyObject
{
  var viewStates: (sidebar: Bool, history: Bool, details: Bool) { get }

  func goBack()
  func goForward()
  func fetchSelected()
  func pushSelected()
  func pullSelected()
  func stashSelected()
  func popStashSelected()
  func applyStashSelected()
  func dropStashSelected()
  func showHideSidebar()
  func showHideHistory()
  func showHideDetails()
  func search(for text: String,
              type: HistorySearchType,
              direction: SearchDirection)
}

@MainActor
class TitleBarController: NSObject
{
  @IBOutlet weak var window: NSWindow!
  @IBOutlet weak var navButtons: NSSegmentedControl!
  @IBOutlet weak var remoteControls: NSSegmentedControl!
  @IBOutlet weak var stashButton: NSSegmentedControl!
  @IBOutlet weak var spinner: NSProgressIndicator!
  @IBOutlet weak var viewControls: NSSegmentedControl!
  var stashMenu: NSMenu!
  var fetchMenu: NSMenu!
  var pushMenu: NSMenu!
  var pullMenu: NSMenu!
  var remoteOpsMenu: NSMenu!
  var viewMenu: NSMenu!
  @IBOutlet var splitView: NSSplitView!

  weak var delegate: (any TitleBarDelegate)?
  
  var progressSink: AnyCancellable?
  
  var separatorItem: NSToolbarItem?
  private var searchToolbarItem: NSSearchToolbarItem?
  private var previousSearchItem: NSToolbarItem?
  private var nextSearchItem: NSToolbarItem?
  private var searchTypeItems: [NSMenuItem] = []
  private var searchEnabled = true
  private var searchText = ""
  private var searchType: HistorySearchType = .summary {
    didSet {
      updateSearchTypeMenuState()
      updateSearchPlaceholder()
    }
  }
  
  @objc dynamic var progressHidden: Bool
  {
    get
    { spinner.isHidden }
    set
    {
      spinner.isIndeterminate = true
      spinner.isHidden = newValue
      if newValue {
        spinner.stopAnimation(nil)
      }
      else {
        spinner.startAnimation(nil)
      }
    }
  }
  
  enum NavSegment: Int
  {
    case back, forward
  }
  
  enum RemoteSegment: Int
  {
    case pull, push, fetch
  }
  
  enum ViewSegment: Int
  {
    case sidebar, history, details
  }

  @MainActor
  override func awakeFromNib()
  {
    super.awakeFromNib()
    makeMenus()
  }

  private func makeMenus()
  {
    fetchMenu = NSMenu {
      NSMenuItem(.fetchAllRemotes,
                 action: #selector(XTWindowController.fetchAllRemotes(_:)))
      NSMenuItem(.fetchCurrentUnavailable,
                 action: #selector(XTWindowController.fetchCurrentBranch(_:)))
      NSMenuItem.separator()
        .with(identifier: XTWindowController.RemoteMenuType.fetch.identifier)
      NSMenuItem(.fetchRemote("unknown"),
                 action: #selector(XTWindowController.fetchRemote(_:)))
    }
    fetchMenu.setAccessibilityIdentifier(AXID.PopupMenu.fetch)
    pullMenu = NSMenu {
      NSMenuItem(.pull,
                 action: #selector(XTWindowController.pullCurrentBranch(_:)))
    }
    pullMenu.setAccessibilityIdentifier(AXID.PopupMenu.pull)
    pushMenu = NSMenu {
      NSMenuItem(.pushNew,
                 action: #selector(XTWindowController.push(_:)))
      NSMenuItem.separator()
        .with(identifier: XTWindowController.RemoteMenuType.push.identifier)
      NSMenuItem(.pushToRemote,
                 action: #selector(XTWindowController.pushToRemote(_:)))
    }
    pushMenu.setAccessibilityIdentifier(AXID.PopupMenu.push)
    stashMenu = NSMenu {
      NSMenuItem(.saveStash,
                 systemImage: "tray.and.arrow.down.fill",
                 action: #selector(XTWindowController.stash(_:)))
      NSMenuItem.separator()
      NSMenuItem(.pop,
                 systemImage: "tray.and.arrow.up.fill",
                 action: #selector(XTWindowController.popStash(_:)))
      NSMenuItem(.apply,
                 systemImage: "tray.and.arrow.up",
                 action: #selector(XTWindowController.applyStash(_:)))
      NSMenuItem(.drop,
                  systemImage: "trash",
                 action: #selector(XTWindowController.dropStash(_:)))
    }
    remoteOpsMenu = NSMenu {
      NSMenuItem(.pull,
                 systemImage: "square.and.arrow.down.fill",
                 action: #selector(XTWindowController.pull(_:)))
      NSMenuItem(.push,
                 systemImage: "square.and.arrow.up.fill",
                 action: #selector(XTWindowController.push(_:)))
      NSMenuItem(.fetch,
                 systemImage: "square.and.arrow.down",
                 action: #selector(XTWindowController.fetch(_:)))
    }
    viewMenu = NSMenu {
      NSMenuItem(.sidebar,
                 action: #selector(XTWindowController.showHideSidebar(_:)))
      NSMenuItem(.history,
                 action: #selector(XTWindowController.showHideHistory(_:)))
      NSMenuItem(.files,
                 action: #selector(XTWindowController.showHideDetails(_:)))
    }

    guard let controller = window.windowController as? XTWindowController
    else {
      assertionFailure("can't get window controller")
      return
    }
    let menus = [fetchMenu, pullMenu, pushMenu,
                 stashMenu, remoteOpsMenu, viewMenu]

    for menu in menus {
      menu?.delegate = controller
    }
  }
  
  func finishSetup()
  {
    remoteOpsMenu.items[0].submenu = pullMenu
    remoteOpsMenu.items[1].submenu = pushMenu
    remoteOpsMenu.items[2].submenu = fetchMenu
    installSearchItems()
    updateSearchControls()
  }
  
  func observe(controller: any RepositoryController)
  {
    progressSink = controller.progressPublisher
      .receive(on: DispatchQueue.main)
      .sink {
        (progress, total) in
        
        if progress < total {
          self.spinner.isIndeterminate = false
          self.spinner.startAnimation(nil)
          self.spinner.maxValue = Double(total)
          self.spinner.doubleValue = Double(progress)
          self.spinner.needsDisplay = true
        }
        else {
          self.spinner.stopAnimation(nil)
          self.spinner.isHidden = true
        }
    }
  }

  @IBAction
  func navigate(_ sender: Any?)
  {
    guard let control = sender as? NSSegmentedControl,
          let segment = NavSegment(rawValue: control.selectedSegment)
    else { return }
    
    switch segment {
      case .back:
        delegate?.goBack()
      case .forward:
        delegate?.goForward()
    }
  }
  
  @IBAction
  func remoteAction(_ sender: Any?)
  {
    guard let control = sender as? NSSegmentedControl,
          let segment = RemoteSegment(rawValue: control.selectedSegment)
    else { return }
    
    switch segment {
      case .fetch:
        delegate?.fetchSelected()
      case .pull:
        delegate?.pullSelected()
      case .push:
        delegate?.pushSelected()
    }
  }
  
  @IBAction
  func stash(_ sender: Any)
  {
    delegate?.stashSelected()
  }
  
  @IBAction
  func popStash(_ sender: Any)
  {
    delegate?.popStashSelected()
  }
  
  @IBAction
  func applyStash(_ sender: Any)
  {
    delegate?.applyStashSelected()
  }
  
  @IBAction
  func dropStash(_ sender: Any)
  {
    delegate?.dropStashSelected()
  }
  
  @IBAction
  func viewAction(_ sender: NSSegmentedControl)
  {
    guard let segment = ViewSegment(rawValue: sender.selectedSegment),
          let delegate = self.delegate
    else { return }
    
    switch segment {
      case .sidebar:
        delegate.showHideSidebar()
      case .history:
        delegate.showHideHistory()
      case .details:
        delegate.showHideDetails()
    }
    
    updateViewControls()
  }
  
  @IBAction func viewSidebar(_ sender: NSMenuItem)
  {
    delegate?.showHideSidebar()
  }
  
  @IBAction func viewHistory(_ sender: NSMenuItem)
  {
    delegate?.showHideHistory()
  }
  
  @IBAction func viewFiles(_ sender: NSMenuItem)
  {
    delegate?.showHideDetails()
  }

  func updateViewControls()
  {
    guard let states = delegate?.viewStates
    else { return }
    
    viewControls.setSelected(states.sidebar, forSegment: 0)
    viewControls.setSelected(states.history, forSegment: 1)
    viewControls.setSelected(states.details, forSegment: 2)
  }

  func setSearchEnabled(_ enabled: Bool)
  {
    searchEnabled = enabled
    if !enabled {
      hideSearch()
    }
    updateSearchControls()
  }

  func showSearch()
  {
    guard searchEnabled
    else { return }

    searchToolbarItem?.beginSearchInteraction()
    if let item = searchToolbarItem {
      window.makeFirstResponder(item.searchField)
    }
    updateSearchControls()
  }

  func search(_ direction: SearchDirection)
  {
    guard searchEnabled
    else { return }

    showSearch()
    guard !searchText.isEmpty
    else { return }
    delegate?.search(for: searchText,
                     type: searchType,
                     direction: direction)
  }

  func useSelectionForSearch(_ text: String)
  {
    guard let field = searchToolbarItem?.searchField,
          searchEnabled
    else { return }

    showSearch()
    searchText = text
    field.stringValue = text
    updateSearchControls()
  }

  var canShowSearch: Bool
  { searchEnabled }

  var canNavigateSearch: Bool
  { searchEnabled && !searchText.isEmpty }

  private func installSearchItems()
  {
    guard let toolbar = window.toolbar
    else {
      assertionFailure("no toolbar")
      return
    }
    guard !toolbar.items.contains(where: { $0.itemIdentifier == .historySearch })
    else { return }

    if let oldSearchIndex = toolbar.items.firstIndex(where: { $0.itemIdentifier == .search }) {
      toolbar.removeItem(at: oldSearchIndex)
    }
    let trailingIndex = toolbar.items.firstIndex(where: { $0.itemIdentifier == .view })
      .map { $0 + 1 } ?? toolbar.items.count

    toolbar.insertItem(withItemIdentifier: .searchPrevious, at: trailingIndex)
    toolbar.insertItem(withItemIdentifier: .searchNext, at: trailingIndex + 1)
    toolbar.insertItem(withItemIdentifier: .historySearch, at: trailingIndex + 2)
  }

  private func updateSearchControls()
  {
    let hasQuery = !searchText.isEmpty

    searchToolbarItem?.isEnabled = searchEnabled
    previousSearchItem?.isEnabled = searchEnabled && hasQuery
    nextSearchItem?.isEnabled = searchEnabled && hasQuery
    window.toolbar?.validateVisibleItems()
  }

  private func updateSearchTypeMenuState()
  {
    for (index, item) in searchTypeItems.enumerated() {
      item.state = HistorySearchType.allCases[index] == searchType ? .on : .off
    }
  }

  private func updateSearchPlaceholder()
  {
    searchToolbarItem?.searchField.placeholderString =
      "Search \(searchType.displayName.rawValue)"
  }

  private func hideSearch()
  {
    searchText = ""
    searchToolbarItem?.endSearchInteraction()
    searchToolbarItem?.searchField.stringValue = ""
    updateSearchControls()
  }

  private func makeSearchMenu() -> NSMenu
  {
    let menu = NSMenu()
    let titleItem = NSMenuItem(title: "Search In", action: nil, keyEquivalent: "")

    searchTypeItems = []
    menu.autoenablesItems = false
    titleItem.isEnabled = false
    menu.addItem(titleItem)
    menu.addItem(.separator())
    for (index, type) in HistorySearchType.allCases.enumerated() {
      let item = NSMenuItem(title: type.displayName.rawValue,
                            action: #selector(selectSearchType(_:)),
                            keyEquivalent: "")

      item.target = self
      item.tag = index
      menu.addItem(item)
      searchTypeItems.append(item)
    }
    updateSearchTypeMenuState()
    return menu
  }

  private func makeSearchToolbarItem() -> NSSearchToolbarItem
  {
    let item = NSSearchToolbarItem(itemIdentifier: .historySearch)
    let field = item.searchField

    item.label = "Search"
    item.paletteLabel = "Search"
    item.toolTip = "Search History"
    item.preferredWidthForSearchField = 220
    item.resignsFirstResponderWithCancel = true
    field.delegate = self
    field.target = self
    field.action = #selector(runSearch(_:))
    field.sendsWholeSearchString = true
    field.sendsSearchStringImmediately = false
    field.searchMenuTemplate = makeSearchMenu()
    field.setAccessibilityIdentifier(.Search.field)
    searchToolbarItem = item
    updateSearchPlaceholder()
    return item
  }

  private func makeSearchNavigationItem(identifier: NSToolbarItem.Identifier,
                                        label: String,
                                        image: String,
                                        action: Selector) -> NSToolbarItem
  {
    let item = NSToolbarItem(itemIdentifier: identifier)

    item.label = label
    item.paletteLabel = label
    item.toolTip = label
    item.image = .init(systemSymbolName: image, accessibilityDescription: label)
    item.target = self
    item.action = action
    item.isBordered = true
    return item
  }

  @objc
  private func runSearch(_ sender: NSSearchField)
  {
    searchText = sender.stringValue
    search(.down)
  }

  @objc
  private func selectSearchType(_ sender: NSMenuItem)
  {
    guard HistorySearchType.allCases.indices.contains(sender.tag)
    else { return }
    searchType = HistorySearchType.allCases[sender.tag]
  }

  @objc
  private func searchPrevious(_ sender: Any?)
  {
    search(.up)
  }

  @objc
  private func searchNext(_ sender: Any?)
  {
    search(.down)
  }
}

extension NSToolbarItem.Identifier
{
  static let navigation: Self = ◊"xit.nav"
  static let spinner: Self = ◊"xit.spinner"
  static let remoteOps: Self = ◊"xit.remote"
  static let stash: Self = ◊"xit.stash"
  static let search: Self = ◊"xit.search"
  static let historySearch: Self = ◊"xit.historySearch"
  static let searchPrevious: Self = ◊"xit.searchPrevious"
  static let searchNext: Self = ◊"xit.searchNext"
  static let view: Self = ◊"xit.view"
}

extension TitleBarController: NSToolbarDelegate
{
  func toolbar(_ toolbar: NSToolbar,
               itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
               willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem?
  {
    if itemIdentifier == .sidebarTrackingSeparator {
      // Return the saved item to avoid Cocoa throwing exceptions about only
      // one tracking item being allowed.
      return separatorItem
    }
    if itemIdentifier == .historySearch {
      return searchToolbarItem ?? makeSearchToolbarItem()
    }
    if itemIdentifier == .searchPrevious {
      let item = previousSearchItem
        ?? makeSearchNavigationItem(identifier: .searchPrevious,
                                    label: "Find Previous",
                                    image: "chevron.up",
                                    action: #selector(searchPrevious(_:)))

      previousSearchItem = item
      return item
    }
    if itemIdentifier == .searchNext {
      let item = nextSearchItem
        ?? makeSearchNavigationItem(identifier: .searchNext,
                                    label: "Find Next",
                                    image: "chevron.down",
                                    action: #selector(searchNext(_:)))

      nextSearchItem = item
      return item
    }
    return nil
  }
  
  func toolbarWillAddItem(_ notification: Notification)
  {
    guard let item = notification.userInfo?["item"] as? NSToolbarItem
    else { return }

    if fetchMenu == nil {
      makeMenus()
    }
    
    switch item.itemIdentifier {
      case .navigation:
        navButtons = item.view as? NSSegmentedControl
        
      case .spinner:
        spinner = item.view as? NSProgressIndicator
        
      case .remoteOps:
        remoteControls = item.view as? NSSegmentedControl
        
        let menuItem = NSMenuItem(title: item.label, action: nil,
                                  keyEquivalent: "")
        
        menuItem.submenu = remoteOpsMenu
        item.menuFormRepresentation = menuItem
        
      case .stash:
        let segmentMenus: [(NSMenu, TitleBarController.RemoteSegment)] = [
              (pullMenu, .pull),
              (pushMenu, .push),
              (fetchMenu, .fetch)]

        stashButton = item.view as? NSSegmentedControl
        for (menu, segment) in segmentMenus {
          remoteControls.setMenu(menu, forSegment: segment.rawValue)
        }
        stashButton.setMenu(stashMenu, forSegment: 0)
    
      case .view:
        viewControls = item.view as? NSSegmentedControl
        
        let menuItem = NSMenuItem(title: item.label, action: nil,
                                  keyEquivalent: "")
        
        menuItem.submenu = viewMenu
        item.menuFormRepresentation = menuItem
      
      case .sidebarTrackingSeparator:
        separatorItem = item
        
      default:
        return
    }
  }
}

extension TitleBarController: NSMenuItemValidation
{
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    guard let states = delegate?.viewStates
    else { return false }
    let state: Bool
    
    switch menuItem.action {
      case #selector(viewSidebar(_:)):
        state = states.sidebar
      case #selector(viewHistory(_:)):
        state = states.history
      case #selector(viewFiles(_:)):
        state = states.details
      case #selector(selectSearchType(_:)):
        return true
      default:
        return false
    }
    menuItem.state = state ? .on : .off
    return true
  }
}

extension TitleBarController: NSToolbarItemValidation
{
  func validateToolbarItem(_ item: NSToolbarItem) -> Bool
  {
    switch item.itemIdentifier {
      case .historySearch:
        return searchEnabled
      case .searchPrevious, .searchNext:
        return searchEnabled && !searchText.isEmpty
      default:
        return true
    }
  }
}

extension TitleBarController: NSSearchFieldDelegate
{
  func controlTextDidChange(_ obj: Notification)
  {
    if let field = obj.object as? NSSearchField {
      searchText = field.stringValue
    }
    updateSearchControls()
  }

  func controlTextDidBeginEditing(_ obj: Notification)
  {
    updateSearchControls()
  }

  func controlTextDidEndEditing(_ obj: Notification)
  {
    guard let field = obj.object as? NSSearchField
    else { return }
    if field.stringValue.isEmpty {
      searchText = ""
      hideSearch()
    }
    else {
      searchText = field.stringValue
    }
    updateSearchControls()
  }

  func searchFieldDidStartSearching(_ sender: NSSearchField)
  {
    searchText = sender.stringValue
    updateSearchControls()
  }

  func searchFieldDidEndSearching(_ sender: NSSearchField)
  {
    searchText = ""
    sender.stringValue = ""
    updateSearchControls()
  }
}
