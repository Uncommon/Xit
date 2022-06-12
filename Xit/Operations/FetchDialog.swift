import Cocoa
import SwiftUI

struct FetchDialog: SheetDialog
{
  typealias ContentView = FetchPanel
  typealias Repository = RepoConfiguring & RemoteManagement & CommitReferencing

  var acceptButtonTitle: UIString { .fetch }

  let repository: Repository

  func createModel() -> FetchPanel.Options?
  {
    let config = repository.config
    guard let defaultRemote = defaultRemoteName()
    else { return nil }
    let model = FetchPanel.Options(
          remotes: repository.remoteNames(),
          remote: defaultRemote,
          downloadTags: config.fetchTags(remote: defaultRemote),
          pruneBranches: config.fetchPrune(remote: defaultRemote))

    return model
  }

  /// The default remote to fetch from.
  ///
  /// Returns either:
  /// - the current branch's tracking branch
  /// - the remote named "origin"
  /// - the one remote, if there is only one
  func defaultRemoteName() -> String?
  {
    if let branchName = repository.currentBranch {
      let currentBranch = repository.localBranch(named: branchName)

      if let trackingBranch = currentBranch?.trackingBranch {
        return trackingBranch.remoteName
      }
    }

    let remotes = repository.remoteNames()

    if remotes.isEmpty {
      return nil
    }
    else {
      for remote in remotes where remote == "origin" {
        return remote
      }
      return remotes.first
    }
  }
}
