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
    historyController.mainSplitView.isVertical = true
    historyController.mainSplitView.adjustSubviews()
  }
  
  @IBAction func horizontalLayout(_ sender: AnyObject)
  {
    historyController.mainSplitView.isVertical = false
    historyController.mainSplitView.adjustSubviews()
  }
  
  @IBAction func deemphasizeMerges(_ sender: AnyObject)
  {
    Preferences.deemphasizeMerges = !Preferences.deemphasizeMerges
    redrawAllHistoryLists()
  }
  
  @IBAction func newTag(_: AnyObject)
  {
    _ = startOperation { NewTagOpController(windowController: self) }
  }
  
  @IBAction func newBranch(_: AnyObject) {}
  @IBAction func addRemote(_: AnyObject) {}

  @IBAction func goBack(_: AnyObject)
  {
    withNavigating {
      selection.map { navForwardStack.append($0) }
      selection = navBackStack.popLast()
    }
  }
  
  @IBAction func goForward(_: AnyObject)
  {
    withNavigating {
      selection.map { navBackStack.append($0) }
      selection = navForwardStack.popLast()
    }
  }

  @IBAction func fetch(_: AnyObject)
  {
    let _: FetchOpController? = startOperation()
  }
  
  @IBAction func pull(_: AnyObject)
  {
    let _: PullOpController? = startOperation()
  }
  
  @IBAction func push(_: AnyObject)
  {
    let _: PushOpController? = startOperation()
  }
  
  @IBAction func stash(_: AnyObject)
  {
    let _: StashOperationController? = startOperation()
  }
  
  @IBAction func remoteSettings(_ sender: AnyObject)
  {
    guard let menuItem = sender as? NSMenuItem
    else { return }
    
    let controller = RemoteOptionsOpController(windowController: self,
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
