import Foundation

extension NSTouchBarItem.Identifier
{
  static let
      navigation = NSTouchBarItem.Identifier("com.uncommonplace.xit.nav"),
      staging = NSTouchBarItem.Identifier("com.uncommonplace.xit.staging"),
      stage = NSTouchBarItem.Identifier("com.uncommonplace.xit.stage"),
      revert = NSTouchBarItem.Identifier("com.uncommonplace.xit.revert"),
      unstage = NSTouchBarItem.Identifier("com.uncommonplace.xit.unstage"),
      unstageAll = NSTouchBarItem.Identifier("com.uncommonplace.xit.unstageall"),
      stageAll = NSTouchBarItem.Identifier("com.uncommonplace.xit.stageall")
}

@available(OSX 10.12.2, *)
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
    let listController =
          historyController.fileViewController.activeFileListController
    
    switch identifier {

      case NSTouchBarItem.Identifier.navigation:
        let control = NSSegmentedControl(
                images: [NSImage(named: NSImage.goBackTemplateName)!,
                         NSImage(named: NSImage.goForwardTemplateName)!],
                trackingMode: .momentary,
                target: titleBarController,
                action: #selector(TitleBarViewController.navigate(_:)))
        let item = NSCustomTouchBarItem(identifier: identifier)
      
        control.segmentStyle = .separated
        item.view = control
        return item

      case .stage:
        return touchBarButton(
            identifier: identifier, title: .stage,
            image: NSImage(named: .xtStageButtonHover),
            target: listController,
            action: #selector(WorkspaceFileListController.stage(_:)))

      case .revert:
        return touchBarButton(
            identifier: identifier, title: .revert,
            image: NSImage(named: .xtRevertTemplate),
            target: listController,
            action: #selector(WorkspaceFileListController.revert(_:)))
      
      case .unstage:
        return touchBarButton(
            identifier: identifier, title: .unstage,
            image: NSImage(named: .xtUnstageButtonHover),
            target: listController,
            action: #selector(StagedFileListController.unstage(_:)))

      case NSTouchBarItem.Identifier.staging:
        guard let stagingImage = NSImage(named: .xtStagingTemplate)
        else { return nil }
      
        return touchBarButton(
            identifier: identifier, title: .staging,
            image: stagingImage,
            target: self, action: #selector(XTWindowController.showStaging(_:)))

      case NSTouchBarItem.Identifier.unstageAll:
        return touchBarButton(
            identifier: identifier, title: .unstageAll,
            image: NSImage(named: .xtUnstageAllTemplate),
            target: historyController.fileViewController,
            action: #selector(FileViewController.unstageAll(_:)))
      
      case NSTouchBarItem.Identifier.stageAll:
        return touchBarButton(
            identifier: identifier, title: .stageAll,
            image: NSImage(named: .xtStageAllTemplate),
            target: historyController.fileViewController,
            action: #selector(FileViewController.stageAll(_:)))

      default:
        return nil
    }
  }
  
  @IBAction
  func showStaging(_ sender: Any?)
  {
    guard let outline = sidebarController.sidebarOutline
    else { return }
    let stagingRow = outline.row(forItem: sidebarController.sidebarDS.stagingItem)
  
    outline.selectRowIndexes(IndexSet(integer: stagingRow),
                             byExtendingSelection: false)
  }
}
