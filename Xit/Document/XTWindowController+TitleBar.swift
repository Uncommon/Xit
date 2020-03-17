import Foundation

extension XTWindowController
{
  func updateBranchList()
  {
    guard let repo = xtDocument?.repository
    else { return }

    titleBarController?.updateBranchList(
        repo.localBranches.compactMap { $0.shortName },
        current: repo.currentBranch)
  }

  func updateNavButtons()
  {
    updateNavControl(titleBarController?.navButtons)

    if #available(OSX 10.12.2, *),
       let item = touchBar?.item(forIdentifier:
                                 NSTouchBarItem.Identifier.navigation) {
      updateNavControl(item.view as? NSSegmentedControl)
    }
  }

  func updateNavControl(_ control: NSSegmentedControl?)
  {
    guard let control = control
    else { return }

    control.setEnabled(!navBackStack.isEmpty, forSegment: 0)
    control.setEnabled(!navForwardStack.isEmpty, forSegment: 1)
  }

  func configureTitleBarController(repository: XTRepository)
  {
    let viewController: TitleBarViewController = titleBarController!
    let inverseBindingOptions =
      [NSBindingOption.valueTransformerName:
        NSValueTransformerName.negateBooleanTransformerName]

    viewController.proxyIcon.bind(NSBindingName.hidden,
                                  to: queue,
                                  withKeyPath: #keyPath(TaskQueue.busy),
                                  options: nil)
    viewController.bind(.progressHidden,
                        to: queue,
                        withKeyPath: #keyPath(TaskQueue.busy),
                        options: inverseBindingOptions)
    viewController.selectedBranch = repository.currentBranch
    viewController.observe(repository: repository)
    updateBranchList()
  }
}

extension XTWindowController: TitleBarDelegate
{
  func branchSelecetd(_ branch: String)
  {
    try? xtDocument!.repository!.checkOut(branch: branch)
  }

  var viewStates: (sidebar: Bool, history: Bool, details: Bool)
  {
    return (!sidebarHidden,
            !historyController.historyHidden,
            !historyController.detailsHidden)
  }

  func goBack() { goBack(self) }
  func goForward() { goForward(self) }
  func fetchSelected() { fetch(self) }
  func pushSelected() { push(self) }
  func pullSelected() { pull(self) }
  func stashSelected() { stash(self) }
  func popStashSelected() { popStash(self) }
  func applyStashSelected() { applyStash(self) }
  func dropStashSelected() { dropStash(self) }
  func showHideSidebar() { showHideSidebar(self) }
  func showHideHistory() { showHideHistory(self) }
  func showHideDetails() { showHideDetails(self) }

  func search()
  {
    historyController.toggleScopeBar()
  }
}

extension XTWindowController: NSToolbarDelegate
{
  func toolbarWillAddItem(_ notification: Notification)
  {
    guard let item = notification.userInfo?["item"] as? NSToolbarItem,
          item.itemIdentifier.rawValue == "com.uncommonplace.xit.titlebar"
    else { return }

    let viewController = TitleBarViewController(nibName: .titleBarNib,
                                                bundle: nil)

    titleBarController = viewController
    item.view = viewController.view

    viewController.delegate = self
    viewController.titleLabel.bind(NSBindingName.value,
                                   to: window! as NSWindow,
                                   withKeyPath: #keyPath(NSWindow.title),
                                   options: nil)
    viewController.spinner.startAnimation(nil)
  }
}
