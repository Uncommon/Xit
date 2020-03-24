import Foundation

extension XTWindowController
{
  @IBAction
  func refresh(_ sender: AnyObject)
  {
    historyController.reload()
    sidebarController.reload()
  }
  
  @IBAction
  func showHideSidebar(_ sender: AnyObject)
  {
    let wasCollapsed = splitViewController.splitViewItems[0].isCollapsed
    
    splitViewController.splitViewItems[0].isCollapsed = !wasCollapsed
    titleBarController!.viewControls.setSelected(!wasCollapsed, forSegment: 0)
  }
  
  @IBAction
  func showHideHistory(_ sender: AnyObject)
  {
    historyController.toggleHistory(sender)
    historyAutoCollapsed = false
  }
  
  @IBAction
  func showHideDetails(_ sender: AnyObject)
  {
    historyController.toggleDetails(sender)
  }
  
  @IBAction
  func verticalLayout(_ sender: AnyObject)
  {
    historyController.mainSplitView.isVertical = true
    historyController.mainSplitView.adjustSubviews()
  }
  
  @IBAction
  func horizontalLayout(_ sender: AnyObject)
  {
    historyController.mainSplitView.isVertical = false
    historyController.mainSplitView.adjustSubviews()
  }
  
  @IBAction
  func newTag(_: AnyObject)
  {
    _ = startOperation { NewTagOpController(windowController: self) }
  }
  
  @IBAction
  func newBranch(_: AnyObject)
  {
    _ = startOperation { NewBranchOpController(windowController: self) }
  }
  
  @IBAction
  func newRemote(_: AnyObject)
  {
    _ = startOperation { NewRemoteOpController(windowController: self) }
  }

  @IBAction
  func goBack(_: AnyObject)
  {
    withNavigating {
      selection.map { navForwardStack.append($0) }
      selection = navBackStack.popLast()
    }
  }
  
  @IBAction
  func goForward(_: AnyObject)
  {
    withNavigating {
      selection.map { navBackStack.append($0) }
      selection = navForwardStack.popLast()
    }
  }

  @IBAction
  func fetch(_: AnyObject)
  {
    let _: FetchOpController? = startOperation()
  }
  
  @IBAction
  func pull(_: AnyObject)
  {
    let _: PullOpController? = startOperation()
  }
  
  @IBAction
  func push(_: AnyObject)
  {
    let _: PushOpController? = startOperation()
  }
  
  @IBAction
  func stash(_: AnyObject)
  {
    let _: StashOperationController? = startOperation()
  }
  
  func tryRepoOperation(_ operation: () throws -> Void)
  {
    do {
      try operation()
    }
    catch let error as RepoError {
      showErrorMessage(error: error)
    }
    catch {
      showErrorMessage(error: .unexpected)
    }
  }
  
  func noStashesAlert()
  {
    let alert = NSAlert()
    
    alert.messageString = .noStashes
    alert.beginSheetModal(for: window!, completionHandler: nil)
  }
  
  @IBAction
  func popStash(_: AnyObject)
  {
    guard let stash = repository.stashes.first
    else {
      noStashesAlert()
      return
    }
    
    NSAlert.confirm(message: .confirmPop,
                    infoString: stash.message.map { UIString(rawValue: $0) },
                    actionName: .pop, parentWindow: window!) {
      self.tryRepoOperation() {
        try self.repository.popStash(index: 0)
      }
    }
  }
  
  @IBAction
  func applyStash(_: AnyObject)
  {
    guard let stash = repository.stashes.first
    else {
      noStashesAlert()
      return
    }

    NSAlert.confirm(message: .confirmApply,
                    infoString: stash.message.map { UIString(rawValue: $0) },
                    actionName: .apply, parentWindow: window!) {
      self.tryRepoOperation() {
        try self.repository.applyStash(index: 0)
      }
    }
  }
  
  @IBAction
  func dropStash(_: AnyObject)
  {
    guard let stash = repository.stashes.first
    else {
      noStashesAlert()
      return
    }

    NSAlert.confirm(message: .confirmStashDelete,
                    infoString: stash.message.map { UIString(rawValue: $0) },
                    actionName: .drop, parentWindow: window!) {
      self.tryRepoOperation() {
        try self.repository.dropStash(index: 0)
      }
    }
  }

  @IBAction
  func remoteSettings(_ sender: AnyObject)
  {
    guard let menuItem = sender as? NSMenuItem
    else { return }
    
    remoteSettings(remote: menuItem.title)
  }
  
  func remoteSettings(remote: String)
  {
    let controller = RemoteOptionsOpController(windowController: self,
                                               remote: remote)
    
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

extension XTWindowController: NSMenuItemValidation
{
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    guard let action = menuItem.action
      else { return false }
    var result = false
    
    switch action {
      
      case #selector(self.goBack(_:)):
        result = !navBackStack.isEmpty

      case #selector(self.goForward(_:)):
        result = !navForwardStack.isEmpty

      case #selector(self.refresh(_:)):
        result = !xtDocument!.repository.isWriting

      case #selector(self.showHideSidebar(_:)):
        result = true
        menuItem.titleString = sidebarHidden ? .showSidebar : .hideSidebar

      case #selector(self.verticalLayout(_:)):
        result = true
        menuItem.state = historyController.mainSplitView.isVertical ? .on : .off

      case #selector(self.horizontalLayout(_:)):
        result = true
        menuItem.state = historyController.mainSplitView.isVertical ? .off : .on

      case #selector(self.remoteSettings(_:)):
        result = true

      case #selector(self.stash(_:)):
        result = true

      case #selector(self.newBranch(_:)):
        result = true

      case #selector(self.newTag(_:)):
        result = true

      case #selector(self.newRemote(_:)):
        result = true
      
      default:
        result = false
    }
    return result
  }
}
