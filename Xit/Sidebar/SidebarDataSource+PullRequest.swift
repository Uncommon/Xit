import Foundation

extension SideBarDataSource: PullRequestClient
{
  func pullRequestUpdated(branch: String, requests: [PullRequest])
  {
    scheduleReload()
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
}
