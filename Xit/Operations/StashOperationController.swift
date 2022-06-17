import Cocoa

final class StashOperationController: SimpleOperationController
{
  override func start() throws
  {
    guard let repo = self.repository,
          let parent = windowController?.window
    else {
      self.ended()
      return
    }

    Task {
      guard let model = await StashDialog().getOptions(parent: parent)
      else {
        self.ended(result: .canceled)
        return
      }

      self.tryRepoOperation {
        try repo.saveStash(name: model.message,
                           keepIndex: model.keepStaged,
                           includeUntracked: model.includeUntracked,
                           includeIgnored: model.includeIgnored)
        self.ended()
      }
    }
  }
}
