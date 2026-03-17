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

  init(repo: some FullRepository,
       workspaceCountModel: WorkspaceStatusCountModel,
       controller: XTWindowController)
  {
    self.controller = controller

    let view = TabbedSidebar(brancher: repo,
                             detector: repo,
                             remoteManager: repo,
                             referencer: repo,
                             publisher: controller.repoController,
                             stasher: repo,
                             submoduleManager: repo,
                             tagger: repo,
                             workspaceCountModel: workspaceCountModel,
                             selection: controller.selectionBinding)
      .environment(\.showError) { [weak controller] error in
        controller?.showAlert(nsError: error)
      }
      .environmentObject(coordinator)
      .environmentObject(accessories)

    super.init(rootView: AnyView(view))
    configureCoordinator()
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

  /// Wires coordinator command closures to existing repository operations and
  /// window-controller UI flows.
  private func configureCoordinator()
  {
    coordinator.newBranchAction = { [weak self] in
      guard let controller = self?.controller else { return }
      controller.startOperation {
        NewBranchOpController(windowController: controller)
      }
    }
    coordinator.newRemoteAction = { [weak self] in
      guard let controller = self?.controller else { return }
      controller.startOperation {
        NewRemoteOpController(windowController: controller)
      }
    }
    coordinator.checkoutBranchAction = { [weak self] branch in
      self?.executeAndReport {
        try self?.controller?.repository.checkOut(branch: branch)
      }
    }
    coordinator.mergeBranchAction = { [weak self] branch in
      self?.mergeLocalBranch(branch)
    }
    coordinator.renameBranchAction = { [weak self] branch in
      guard let controller = self?.controller else { return }
      controller.startOperation {
        RenameBranchOpController(windowController: controller, branchName: branch)
      }
    }
    coordinator.deleteBranchAction = { [weak self] branch in
      self?.confirmDelete(kind: .ItemType.branch, name: branch.name) { value in
        try self?.controller?.repository.deleteBranch(value)
      }(branch)
    }
    coordinator.createTrackingBranchAction = { [weak self] branch in
      guard let controller = self?.controller else { return }
      controller.startOperation {
        CheckOutRemoteOpController(windowController: controller,
                                   branch: branch)
      }
    }
    coordinator.mergeRemoteBranchAction = { [weak self] branch in
      self?.mergeRemoteBranch(branch)
    }
    coordinator.renameRemoteAction = { [weak self] remote in
      self?.controller?.remoteSettings(remote: remote)
    }
    coordinator.editRemoteAction = { [weak self] remote in
      self?.controller?.remoteSettings(remote: remote)
    }
    coordinator.deleteRemoteAction = { [weak self] remote in
      self?.confirmDelete(kind: .ItemType.remote, name: remote) { value in
        try self?.controller?.repository.deleteRemote(named: value)
      }(remote)
    }
    coordinator.copyRemoteURLAction = { [weak self] remote in
      self?.copyRemoteURL(named: remote)
    }
    coordinator.deleteTagAction = { [weak self] tag in
      self?.confirmDelete(kind: .ItemType.tag, name: tag.name) { value in
        try self?.controller?.repository.deleteTag(name: value)
      }(tag)
    }
    coordinator.popStashAction = { [weak self] stashID in
      self?.runStashAction(stashID) { index in
        try self?.controller?.repository.popStash(index: UInt(index))
      }
    }
    coordinator.applyStashAction = { [weak self] stashID in
      self?.runStashAction(stashID) { index in
        try self?.controller?.repository.applyStash(index: UInt(index))
      }
    }
    coordinator.dropStashAction = { [weak self] stashID in
      self?.runStashAction(stashID) { index in
        try self?.controller?.repository.dropStash(index: UInt(index))
      }
    }
    coordinator.showSubmoduleInFinderAction = { [weak self] submoduleName in
      self?.showSubmoduleInFinder(named: submoduleName)
    }
    coordinator.updateSubmoduleAction = { [weak self] submoduleName in
      self?.updateSubmodule(named: submoduleName)
    }
  }

  private func mergeLocalBranch(_ refName: LocalBranchRefName)
  {
    guard let branch = controller?.repository.localBranch(named: refName)
    else { return }

    executeAndReport {
      try self.controller?.repository.merge(branch: branch)
    }
  }

  private func mergeRemoteBranch(_ refName: RemoteBranchRefName)
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
