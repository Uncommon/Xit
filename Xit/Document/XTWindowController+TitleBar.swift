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

    if let item = touchBar?.item(forIdentifier:
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
    let viewController: TitleBarController = titleBarController!
    let inverseBindingOptions =
      [NSBindingOption.valueTransformerName:
        NSValueTransformerName.negateBooleanTransformerName]

    // This can't be connected in the storyboard because TitleBarDelegate is
    // not objc compatible.
    viewController.delegate = self
    viewController.finishSetup()
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
    (!sidebarHidden,
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
