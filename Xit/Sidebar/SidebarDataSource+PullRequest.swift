import Foundation

extension SideBarDataSource: PullRequestClient
{
  func pullRequestUpdated(branch: String, requests: [PullRequest])
  {
    DispatchQueue.main.async {
      if let item = self.item(forBranchName: branch) {
        self.outline.reloadItem(item)
      }
    }
  }
  
  func pullRequest(for item: SidebarItem?) -> PullRequest?
  {
    guard let branchItem = item as? BranchSidebarItem,
          let remote = branchItem.remote,
          let remoteURL = remote.url
    else { return nil }
    let branch = branchItem.branchObject()
    let branchName: String
    
    // Make sure we have the local version of the branch name
    switch branch {
      case let localBranch as LocalBranch:
        branchName = localBranch.name
      case let remoteBranch as RemoteBranch:
        branchName = remoteBranch.localBranchName
      default:
        return nil
    }
    
    return pullRequestCache.requests.first(where: {
      $0.sourceBranch == branchName &&
      $0.matchRemote(url: remoteURL)
    })
  }
  
  func prStatusImage(status: PullRequestStatus,
                     approval: PullRequestApproval) -> NSImage?
  {
    let statusImageName: NSImage.Name?
    
    switch status {
      case .open:
        switch approval {
          case .approved:
            statusImageName = .prApproved
          case .needsWork:
            statusImageName = .prNeedsWork
          case .unreviewed:
            statusImageName = nil
        }
      case .merged:
        statusImageName = .prMerged
      case .inactive:
        statusImageName = .prClosed
      case .other:
        statusImageName = nil
    }
    
    return statusImageName.flatMap { NSImage(named: $0) }
  }
  
  func updatePullRequestMenu(popup: NSPopUpButton, pullRequest: PullRequest)
  {
    let actions = pullRequest.availableActions

    for item in popup.itemArray {
      switch item.action {
        case #selector(SidebarTableCellView.viewPRWebPage(_:)):
          item.isHidden = pullRequest.webURL == nil
        case #selector(SidebarTableCellView.approvePR(_:)):
          item.isHidden = !actions.contains(.approve)
        case #selector(SidebarTableCellView.unapprovePR(_:)):
          item.isHidden = !actions.contains(.unapprove)
        case #selector(SidebarTableCellView.prNeedsWork(_:)):
          item.isHidden = !actions.contains(.needsWork)
        default:
          break
      }
    }
  }
  
  func updatePullRequestButton(item: SidebarItem, view: SidebarTableCellView)
  {
    guard let pullRequest = pullRequest(for: item)
    else {
      view.prContanier.isHidden = true
      return
    }
    
    view.prContanier.isHidden = false
    view.pullRequestButton.toolTip = pullRequest.displayName
    view.prStatusImage.image = prStatusImage(status: pullRequest.status,
                                             approval: pullRequest.userApproval)
    updatePullRequestMenu(popup: view.pullRequestButton,
                          pullRequest: pullRequest)
  }
  
  func viewPRWebPage(item: SidebarItem)
  {
    guard let pullRequest = pullRequest(for: item),
          let url = pullRequest.webURL
    else { return }
    
    NSWorkspace.shared.open(url)
  }
  
  func approvePR(item: SidebarItem)
  {
    guard let pullRequest = pullRequest(for: item)
    else { return }
    
    pullRequest.service.approve(
        request: pullRequest,
        onSuccess: { self.prActionSucceeded(item: item) },
        onFailure: { error in self.prActionFailed(item: item, error: error) })
  }
  
  func unapprovePR(item: SidebarItem)
  {
    guard let pullRequest = pullRequest(for: item)
    else { return }
    
    pullRequest.service.unapprove(
        request: pullRequest,
        onSuccess: { self.prActionSucceeded(item: item) },
        onFailure: { error in self.prActionFailed(item: item, error: error) })
  }
  
  func prNeedsWork(item: SidebarItem)
  {
    guard let pullRequest = pullRequest(for: item)
    else { return }
    
    pullRequest.service.needsWork(
        request: pullRequest,
        onSuccess: { self.prActionSucceeded(item: item) },
        onFailure: { error in self.prActionFailed(item: item, error: error) })
  }
  
  func prActionSucceeded(item: SidebarItem)
  {
    // update the PR cache
    // refresh the item
  }
  
  func prActionFailed(item: SidebarItem, error: Error)
  {
    guard let window = viewController.view.window
    else { return }
    let alert = NSAlert()
    
    alert.messageText = "Pull request action failed."
    alert.informativeText = (error as CustomStringConvertible).description
    alert.beginSheetModal(for: window, completionHandler: nil)
  }
}
