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
      let (message, keepStaged, includeUntracked, includeIgnored) =
        (model.message, model.keepStaged,
         model.includeUntracked, model.includeIgnored)

      self.tryRepoOperation {
        try repo.saveStash(name: message,
                           keepIndex: keepStaged,
                           includeUntracked: includeUntracked,
                           includeIgnored: includeIgnored)
        Task { @MainActor in self.ended() }
      }
    }
  }
}
