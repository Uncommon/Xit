import Foundation

extension XTWindowController
{
  @IBAction func refresh(_ sender: AnyObject)
  {
    historyController.reload()
    sidebarController.reload()
  }
  
  @IBAction func showHideSidebar(_ sender: AnyObject)
  {
    let sidebarPane = mainSplitView.subviews[0]
    let isCollapsed = sidebarHidden
    let newWidth = isCollapsed
                   ? savedSidebarWidth
                   : mainSplitView.minPossiblePositionOfDivider(at: 0)
    
    if !isCollapsed {
      savedSidebarWidth = sidebarPane.frame.size.width
    }
    mainSplitView.setPosition(newWidth, ofDividerAt: 0)
    sidebarPane.isHidden = !isCollapsed
    titleBarController!.viewControls.setSelected(sidebarHidden, forSegment: 0)
  }
  
  @IBAction func showHideHistory(_ sender: AnyObject)
  {
    historyController.toggleHistory(sender)
  }
  
  @IBAction func showHideDetails(_ sender: AnyObject)
  {
    historyController.toggleDetails(sender)
  }
  
  @IBAction func verticalLayout(_ sender: AnyObject)
  {
    self.historyController.mainSplitView.isVertical = true
    self.historyController.mainSplitView.adjustSubviews()
  }
  
  @IBAction func horizontalLayout(_ sender: AnyObject)
  {
    self.historyController.mainSplitView.isVertical = false
    self.historyController.mainSplitView.adjustSubviews()
  }
  
  @IBAction func deemphasizeMerges(_ sender: AnyObject)
  {
    Preferences.deemphasizeMerges = !Preferences.deemphasizeMerges
    redrawAllHistoryLists()
  }
  
  @IBAction func newTag(_: AnyObject)
  {
    _ = startOperation { XTNewTagController(windowController: self) }
  }
  
  @IBAction func newBranch(_: AnyObject) {}
  @IBAction func addRemote(_: AnyObject) {}

  @IBAction func goBack(_: AnyObject)
  {
    withNavigating {
      selectedModel.map { navForwardStack.append($0) }
      selectedModel = navBackStack.popLast()
    }
  }
  
  @IBAction func goForward(_: AnyObject)
  {
    withNavigating {
      selectedModel.map { navBackStack.append($0) }
      selectedModel = navForwardStack.popLast()
    }
  }

  // "Discardable let" is used here to specify the desired return type.
  // swiftlint:disable redundant_discardable_let
  @IBAction func fetch(_: AnyObject)
  {
    let _: XTFetchController? = startOperation()
  }
  
  @IBAction func pull(_: AnyObject)
  {
    let _: XTPullController? = startOperation()
  }
  
  @IBAction func push(_: AnyObject)
  {
    let _: XTPushController? = startOperation()
  }
  // swiftlint:enable redundant_discardable_let
  
  @IBAction func remoteSettings(_ sender: AnyObject)
  {
    guard let menuItem = sender as? NSMenuItem
    else { return }
    
    let controller = XTRemoteOptionsController(windowController: self,
                                               remote: menuItem.title)
    
    _ = try? controller.start()
  }
}

// MARK: Action helpers
extension XTWindowController
{
  fileprivate func withNavigating(_ callback: () -> Void)
  {
    navigating = true
    callback()
    navigating = false
    updateNavButtons()
  }
}
