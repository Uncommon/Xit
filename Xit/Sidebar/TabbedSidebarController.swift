import Foundation
import AppKit
import SwiftUI

class TabbedSidebarController: NSHostingController<AnyView>
{
  weak var controller: XTWindowController?

  struct BranchDelegate: RepoCommandHandler
  {
    weak var controller: XTWindowController?
  }

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
      .environment(\.branchListDelegate, BranchDelegate(controller: controller))

    // Use AnyView because of the environment modifier
    super.init(rootView: AnyView(view))
  }
  
  @MainActor required dynamic init?(coder: NSCoder) 
  {
    fatalError("init(coder:) has not been implemented")
  }
}

@MainActor
protocol RepoCommandHandler
{
  var controller: XTWindowController? { get }
}

extension RepoCommandHandler
{
  /// Executes a block on the repository queue, and reports any errors to the user.
  func executeAndReport(block: @escaping () throws -> Void)
  {
    controller?.repoController.queue.executeTask {
      do {
        try block()
      }
      catch let error {
        show(alert: .init(error: error))
      }
    }
  }

  func show(alert: NSAlert)
  {
    controller?.window.map { alert.beginSheetModal(for: $0) }
  }
}

extension TabbedSidebarController.BranchDelegate: BranchListDelegate
{
  func newBranch()
  {
    guard let controller else { return }
    controller.startOperation {
      NewBranchOpController(windowController: controller)
    }
  }

  func checkOut(_ branch: LocalBranchRefName)
  {
    executeAndReport {
      try controller?.repository.checkOut(branch: branch)
    }
  }

  func merge(_ branch: LocalBranchRefName)
  {
    guard let branch = controller?.repository.localBranch(named: branch)
    else { return }

    executeAndReport {
      // TODO: change merge(branch:) to take ref name
      try controller?.repository.merge(branch: branch)
    }
  }

  func rename(_ branch: LocalBranchRefName)
  {
    guard let controller else { return }
    controller.startOperation {
      RenameBranchOpController(windowController: controller, branchName: branch)
    }
  }

  func delete(_ branch: LocalBranchRefName)
  {
    guard let controller,
          let window = controller.window
    else { return }

    Task {
      guard await NSAlert.confirmDelete(kind: .ItemType.branch,
                                        name: branch.name,
                                        window: window)
      else { return }

      executeAndReport {
        try controller.repository.deleteBranch(branch)
      }
    }
  }
}

