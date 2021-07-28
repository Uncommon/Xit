import Foundation
import SwiftUI
import Combine

final class CleanPanelController: NSWindowController
{
  typealias Repository = FileStatusDetection & FileContents

  let repository: Repository
  let model = CleanData()

  private var folderSubscriber: AnyCancellable?

  init(repository: Repository)
  {
    let panel = CleanPanel(model: model)
    let viewController = NSHostingController(rootView: panel)
    let window = NSWindow(contentViewController: viewController)

    self.repository = repository
    super.init(window: window)

    viewController.rootView = CleanPanel(delegate: self, model: model)
    refresh()

    folderSubscriber = model.$folderMode.sink { self.refresh(folderMode: $0) }

    window.contentViewController = viewController
    window.contentMinSize = viewController.view.intrinsicContentSize
    window.setAccessibilityIdentifier(.Clean.window)
  }

  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }

  func refresh(folderMode: CleanFolderMode)
  {
    model.items = repository.unstagedChanges(
        showIgnored: true,
        recurseUntracked: model.mode != .ignored && folderMode == .recurse,
        useCache: false)
      .filter { $0.status.isCleanable }
      .sorted { $0.path.lastPathComponent.localizedCompare(
                  $1.path.lastPathComponent) == .orderedAscending}
      .map { .init(path: $0.gitPath, ignored: $0.status == .ignored) }
  }
}

extension CleanPanelController: CleanPanelDelegate
{
  func closePanel()
  {
    if let window = self.window {
      window.sheetParent?.endSheet(window)
    }
  }

  func clean(_ files: [String]) throws
  {
    let fileManager = FileManager.default

    for path in files {
      let url = repository.fileURL(path)

      if fileManager.fileExists(atPath: url.path) {
        try fileManager.removeItem(at: url)
      }
    }
  }

  func refresh()
  {
    refresh(folderMode: model.folderMode)
  }
}

extension DeltaStatus
{
  var isCleanable: Bool
  {
    switch self {
      case .added, .ignored, .untracked:
        return true
      default:
        return false
    }
  }
}

extension Binding
{
  init<T>(_ object: T, keyPath: ReferenceWritableKeyPath<T, Value>)
  {
    self.init(get: { object[keyPath: keyPath] },
              set: { object[keyPath: keyPath] = $0 })
  }
}
