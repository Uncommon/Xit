import Foundation

extension NSTouchBarItem.Identifier
{
  static let
      navigation = Self("com.uncommonplace.xit.nav"),
      staging = Self("com.uncommonplace.xit.staging"),
      stage = Self("com.uncommonplace.xit.stage"),
      revert = Self("com.uncommonplace.xit.revert"),
      unstage = Self("com.uncommonplace.xit.unstage"),
      unstageAll = Self("com.uncommonplace.xit.unstageall"),
      stageAll = Self("com.uncommonplace.xit.stageall")
}

extension XTWindowController: NSTouchBarDelegate
{
  override func makeTouchBar() -> NSTouchBar?
  {
    let bar = NSTouchBar()
    var ids: [NSTouchBarItem.Identifier]
    
    bar.delegate = self
    if selection is StagingSelection {
      let fileViewController = historyController.fileViewController!
      
      switch fileViewController.activeFileListController {
        case fileViewController.stagedListController:
          ids = [ .navigation, .unstage, .unstageAll, .stageAll ]
        case fileViewController.workspaceListController:
          ids = [ .navigation, .stage, .revert, .unstageAll, .stageAll ]
        default:
          ids = [ .navigation ]
      }
    }
    else {
      ids = [ .navigation, .staging ]
    }
    
    bar.defaultItemIdentifiers = ids
    validate(touchBar: bar)
    return bar
  }
  
  func validate(touchBar: NSTouchBar)
  {
    for id in touchBar.itemIdentifiers {
      guard let item = touchBar.item(forIdentifier: id),
            let control = item.view as? NSControl,
            let validator = control.target as? NSUserInterfaceValidations,
            let validatedItem = item.view as? NSValidatedUserInterfaceItem
      else { continue }
      
      control.isEnabled = validator.validateUserInterfaceItem(validatedItem)
    }
  }
  
  func validateTouchBar()
  {
    if let touchBar = touchBar {
      validate(touchBar: touchBar)
    }
  }
  
  func touchBarButton(identifier: NSTouchBarItem.Identifier,
                      title: UIString, image: NSImage?,
                      target: Any, action: Selector) -> NSCustomTouchBarItem
  {
    let item = NSCustomTouchBarItem(identifier: identifier)
    
    if let image = image {
      item.view = NSButton(title: title.rawValue, image: image,
                           target: target, action: action)
    }
    else {
      item.view = NSButton(title: title.rawValue, target: target, action: action)
    }
    return item
  }
  
  func touchBar(_ touchBar: NSTouchBar,
                makeItemForIdentifier identifier: NSTouchBarItem.Identifier)
                -> NSTouchBarItem?
  {
    guard historyController.fileViewController.activeFileList != nil
    else { return nil }
    let listController =
          historyController.fileViewController.activeFileListController
    
    switch identifier {

      case .navigation:
        let control = NSSegmentedControl(
                images: [NSImage(named: NSImage.goBackTemplateName)!,
                         NSImage(named: NSImage.goForwardTemplateName)!],
                trackingMode: .momentary,
                target: titleBarController,
                action: #selector(TitleBarController.navigate(_:)))
        let item = NSCustomTouchBarItem(identifier: identifier)
      
        control.segmentStyle = .separated
        item.view = control
        return item

      case .stage:
        return touchBarButton(
            identifier: identifier, title: .stage,
            image: .xtStageButtonHover,
            target: listController,
            action: #selector(WorkspaceFileListController.stage(_:)))

      case .revert:
        return touchBarButton(
            identifier: identifier, title: .revert,
            image: .xtUndo,
            target: listController,
            action: #selector(WorkspaceFileListController.revert(_:)))
      
      case .unstage:
        return touchBarButton(
            identifier: identifier, title: .unstage,
            image: .xtUnstageButtonHover,
            target: listController,
            action: #selector(StagedFileListController.unstage(_:)))

      case .staging:
        return touchBarButton(
            identifier: identifier, title: .staging,
            image: .xtStaging,
            target: self, action: #selector(XTWindowController.showStaging(_:)))

      case .unstageAll:
        return touchBarButton(
            identifier: identifier, title: .unstageAll,
            image: NSImage(named: .xtUnstageAllTemplate),
            target: historyController.fileViewController as Any,
            action: #selector(FileViewController.unstageAll(_:)))
      
      case .stageAll:
        return touchBarButton(
            identifier: identifier, title: .stageAll,
            image: NSImage(named: .xtStageAllTemplate),
            target: historyController.fileViewController as Any,
            action: #selector(FileViewController.stageAll(_:)))

      default:
        return nil
    }
  }
  
  @IBAction
  func showStaging(_ sender: Any?)
  {
//    guard let outline = sidebarController.sidebarOutline
//    else { return }
//    let stagingRow = outline.row(forItem: sidebarController.sidebarDS.stagingItem)
//  
//    outline.selectRowIndexes(IndexSet(integer: stagingRow),
//                             byExtendingSelection: false)
  }
}
