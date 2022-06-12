import Cocoa
import SwiftUI

class FetchSheetController: NSWindowController
{
  typealias Repository = RepoConfiguring & RemoteManagement & CommitReferencing

  let options: FetchPanel.Options

  init(options: FetchPanel.Options, remotes: [String],
       accept: @escaping () -> Void, cancel: @escaping () -> Void)
  {
    self.options = options

    let viewController = NSHostingController {
      VStack {
        FetchPanel(remotes: remotes, options: options)
        DialogButtonRow()
          .environment(\.buttons, [
            (.cancel, cancel),
            (.accept(.fetch), accept),
          ])
      }.padding(20)
    }
    let window = NSWindow(contentViewController: viewController)

    window.contentMinSize = viewController.view.intrinsicContentSize
    super.init(window: window)
  }

  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }

  static func getFetchOptions(repository: Repository,
                              parent: NSWindow) async -> FetchPanel.Options?
  {
    let remotes = repository.remoteNames()
    guard let defaultRemote = defaultRemoteName(repository)
    else { return nil }
    let config = repository.config
    let options = FetchPanel.Options(
          remote: defaultRemote,
          downloadTags: config.fetchTags(remote: defaultRemote),
          pruneBranches: config.fetchPrune(remote: defaultRemote))
    var sheet: NSWindow!
    let controller = FetchSheetController(options: options, remotes: remotes) {
      parent.endSheet(sheet, returnCode: .OK)
    } cancel: {
      parent.endSheet(sheet, returnCode: .cancel)
    }
    guard let window = controller.window
    else {
      assertionFailure("missing fetch window")
      return nil
    }

    sheet = window

    guard await parent.beginSheet(window) == .OK
    else { return nil }

    return options
  }

  /// The default remote to fetch from, either:
  /// - the current branch's tracking branch
  /// - if there are multiple remotes, the one named "origin"
  /// - if there is one remote, use that one
  static func defaultRemoteName(_ repository: Repository) -> String?
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

extension NSHostingController
{
  convenience init(@ViewBuilder _ viewBuilder: () -> Content)
  {
    self.init(rootView: viewBuilder())
  }
}
