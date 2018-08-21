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
    
    return pullRequestCache.requests.first(where: {
      $0.sourceBranch == branchItem.title &&
      $0.matchRemote(url: remoteURL)
    })
  }
}
