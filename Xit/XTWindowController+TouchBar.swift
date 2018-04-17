import Foundation

extension NSTouchBarItem.Identifier
{
  static let
      navigation = NSTouchBarItem.Identifier("com.uncommonplace.xit.nav"),
      staging = NSTouchBarItem.Identifier("com.uncommonplace.xit.staging"),
      unstageAll = NSTouchBarItem.Identifier("com.uncommonplace.xit.unstageall"),
      stageAll = NSTouchBarItem.Identifier("com.uncommonplace.xit.stageall")
}

@available(OSX 10.12.2, *)
extension XTWindowController: NSTouchBarDelegate
{
  override func makeTouchBar() -> NSTouchBar?
  {
    let bar = NSTouchBar()
    
    bar.delegate = self
    bar.defaultItemIdentifiers = (selection is StagingSelection)
        ? [ .navigation, .unstageAll, .stageAll ]
        : [ .navigation, .staging ]
    
    return bar
  }
  
  func touchBarButton(identifier: NSTouchBarItem.Identifier,
                      title: String, image: NSImage?,
                      target: Any, action: Selector) -> NSCustomTouchBarItem
  {
    let item = NSCustomTouchBarItem(identifier: identifier)
    
    if let image = image {
      item.view = NSButton(title: title, image: image,
                           target: target, action: action)
    }
    else {
      item.view = NSButton(title: title, target: target, action: action)
    }
    return item
  }
  
  func touchBar(_ touchBar: NSTouchBar,
                makeItemForIdentifier identifier: NSTouchBarItem.Identifier)
                -> NSTouchBarItem?
  {
    switch identifier {

      case NSTouchBarItem.Identifier.navigation:
        let control = NSSegmentedControl(
                images: [NSImage(named: .goBackTemplate)!,
                         NSImage(named: .goForwardTemplate)!],
                trackingMode: .momentary,
                target: titleBarController,
                action: #selector(TitleBarViewController.navigate(_:)))
        let item = NSCustomTouchBarItem(identifier: identifier)
      
        control.segmentStyle = .separated
        item.view = control
        return item

      case NSTouchBarItem.Identifier.staging:
        guard let stagingImage = NSImage(named: .xtStagingTemplate)
        else { return nil }
      
        return touchBarButton(
            identifier: identifier, title: "Staging", image: stagingImage,
            target: self, action: #selector(XTWindowController.showStaging(_:)))

      case NSTouchBarItem.Identifier.unstageAll:
        return touchBarButton(
            identifier: identifier, title: "« Unstage All", image: nil,
            target: historyController.fileViewController,
            action: #selector(FileViewController.unstageAll(_:)))
      
      case NSTouchBarItem.Identifier.stageAll:
        return touchBarButton(
            identifier: identifier, title: "» Stage All", image: nil,
            target: historyController.fileViewController,
            action: #selector(FileViewController.stageAll(_:)))

      default:
        return nil
    }
  }
  
  @IBAction func showStaging(_ sender: Any?)
  {
    guard let outline = sidebarController.sidebarOutline
    else { return }
    let stagingRow = outline.row(forItem: sidebarController.sidebarDS.stagingItem)
  
    outline.selectRowIndexes(IndexSet(integer: stagingRow),
                             byExtendingSelection: false)
  }
}
