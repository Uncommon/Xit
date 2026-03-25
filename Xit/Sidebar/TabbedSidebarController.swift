import Foundation
import AppKit
import SwiftUI

/// AppKit wrapper that hosts the SwiftUI sidebar and bridges it back to the
/// existing window-controller operation flow.
@MainActor
final class TabbedSidebarController: NSHostingController<AnyView>
{
  weak var controller: XTWindowController?

  /// Shared sidebar state injected into the SwiftUI hierarchy.
  let coordinator = SidebarCoordinator()

  /// Shared branch accessory renderer injected into local and remote lists.
  let accessories = BranchAccessoryStore()

  /// Cached SwiftUI sidebar models retained across tab switches and refreshed
  /// in response to explicit sidebar reloads.
  private let viewModels: any SidebarViewModelRefreshing

  init(repo: some FullRepository,
       workspaceCountModel: WorkspaceStatusCountModel,
       controller: XTWindowController)
  {
    self.controller = controller
    let viewModels = SidebarViewModel(brancher: repo,
                                      detector: repo,
                                      remoteManager: repo,
                                      referencer: repo,
                                      publisher: controller.repoController,
                                      stasher: repo,
                                      submoduleManager: repo,
                                      tagger: repo,
                                      workspaceCountModel: workspaceCountModel)
    self.viewModels = viewModels

    let view = TabbedSidebar(brancher: repo,
                             remoteManager: repo,
                             referencer: repo,
                             publisher: controller.repoController,
                             stasher: repo,
                             submoduleManager: repo,
                             tagger: repo,
                             models: viewModels,
                             selection: controller.selectionBinding)
      .environment(\.showError) { [weak controller] error in
        controller?.showAlert(nsError: error)
      }
      .environmentObject(coordinator)
      .environmentObject(accessories)

    super.init(rootView: AnyView(view))
    coordinator.delegate = self
  }
  
  required dynamic init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }

  /// Requests that cached sidebar models refresh their visible data.
  func refresh()
  {
    coordinator.refresh()
  }

  private func mergeLocalBranch(_ refName: LocalBranchRefName)
  {
    guard let branch = controller?.repository.localBranch(named: refName)
    else { return }

    executeAndReport {
      try self.controller?.repository.merge(branch: branch)
    }
  }

  private func performMergeRemoteBranch(_ refName: RemoteBranchRefName)
  {
    guard let branch = controller?.repository.remoteBranch(named: refName.name,
                                                           remote: refName.remoteName)
    else { return }

    executeAndReport {
      try self.controller?.repository.merge(branch: branch)
    }
  }

  private func runStashAction(_ stashID: GitOID,
                              action: @escaping (Int) throws -> Void)
  {
    guard let index = controller?.repository.findStashIndex(stashID)
    else { return }

    executeAndReport {
      try action(index)
    }
  }

  private func showSubmoduleInFinder(named submoduleName: String)
  {
    guard let submodule = controller?.repository.submodules()
      .first(where: { $0.name == submoduleName }),
      let repository = controller?.repository
    else { return }

    NSWorkspace.shared.activateFileViewerSelecting([
      repository.fileURL(submodule.path),
    ])
  }

  private func updateSubmodule(named submoduleName: String)
  {
    guard let controller,
          let submodule = controller.repository.submodules()
            .first(where: { $0.name == submoduleName })
    else { return }

    let callbacks = controller.remoteCallbacks(for: submodule.url)

    executeAndReport {
      try submodule.update(callbacks: callbacks)
    }
  }

  private func copyRemoteURL(named remoteName: String)
  {
    guard let remoteURL = controller?.repository.config
      .urlString(remote: "remote.\(remoteName).url")
    else { return }

    let pasteboard = NSPasteboard.general

    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(remoteURL, forType: .string)
  }

  private func executeAndReport(_ block: @escaping () throws -> Void)
  {
    controller?.repoController.queue.executeTask {
      do {
        try block()
      }
      catch let error as NSError {
        Task { @MainActor in
          self.controller?.showAlert(nsError: error)
        }
      }
    }
  }

  private func confirmDelete<T>(kind: UIString,
                                name: String,
                                action: @escaping (T) throws -> Void)
    -> (T) -> Void
  {
    { [weak self] value in
      guard let window = self?.controller?.window
      else { return }

      Task {
        guard await NSAlert.confirmDelete(kind: kind, name: name, window: window)
        else { return }
        self?.executeAndReport {
          try action(value)
        }
      }
    }
  }
}

extension TabbedSidebarController: SidebarCoordinatorDelegate
{
  func newBranch()
  {
    guard let controller else { return }
    controller.startOperation {
      NewBranchOpController(windowController: controller)
    }
  }

  func newRemote()
  {
    guard let controller else { return }
    controller.startOperation {
      NewRemoteOpController(windowController: controller)
    }
  }

  func checkoutBranch(_ branch: LocalBranchRefName)
  {
    executeAndReport {
      try self.controller?.repository.checkOut(branch: branch)
    }
  }

  func mergeBranch(_ branch: LocalBranchRefName)
  {
    mergeLocalBranch(branch)
  }

  func renameBranch(_ branch: LocalBranchRefName)
  {
    guard let controller else { return }
    controller.startOperation {
      RenameBranchOpController(windowController: controller, branchName: branch)
    }
  }

  func deleteBranch(_ branch: LocalBranchRefName)
  {
    confirmDelete(kind: .ItemType.branch, name: branch.name) { value in
      try self.controller?.repository.deleteBranch(value)
    }(branch)
  }

  func createTrackingBranch(_ branch: RemoteBranchRefName)
  {
    guard let controller else { return }
    controller.startOperation {
      CheckOutRemoteOpController(windowController: controller, branch: branch)
    }
  }

  func mergeRemoteBranch(_ branch: RemoteBranchRefName)
  {
    performMergeRemoteBranch(branch)
  }

  func renameRemote(_ remote: String)
  {
    controller?.remoteSettings(remote: remote)
  }

  func editRemote(_ remote: String)
  {
    controller?.remoteSettings(remote: remote)
  }

  func deleteRemote(_ remote: String)
  {
    confirmDelete(kind: .ItemType.remote, name: remote) { value in
      try self.controller?.repository.deleteRemote(named: value)
    }(remote)
  }

  func copyRemoteURL(_ remote: String)
  {
    copyRemoteURL(named: remote)
  }

  func deleteTag(_ tag: TagRefName)
  {
    confirmDelete(kind: .ItemType.tag, name: tag.name) { value in
      try self.controller?.repository.deleteTag(name: value)
    }(tag)
  }

  func popStash(_ stashID: GitOID)
  {
    runStashAction(stashID) { index in
      try self.controller?.repository.popStash(index: UInt(index))
    }
  }

  func applyStash(_ stashID: GitOID)
  {
    runStashAction(stashID) { index in
      try self.controller?.repository.applyStash(index: UInt(index))
    }
  }

  func dropStash(_ stashID: GitOID)
  {
    runStashAction(stashID) { index in
      try self.controller?.repository.dropStash(index: UInt(index))
    }
  }

  func showSubmoduleInFinder(_ name: String)
  {
    showSubmoduleInFinder(named: name)
  }

  func updateSubmodule(_ name: String)
  {
    updateSubmodule(named: name)
  }

  func refreshSidebar()
  {
    viewModels.refresh()
  }
}
