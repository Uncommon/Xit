import Foundation
import SwiftUI
import Combine

final class CleanPanelController: NSWindowController
{
  typealias Repository = FileStatusDetection & FileContents

  let repository: Repository
  let model = CleanData()

  init(repository: Repository)
  {
    let panel = CleanPanel(model: model)
    let viewController = NSHostingController(rootView: panel)
    let window = NSWindow(contentViewController: viewController)

    self.repository = repository
    super.init(window: window)

    viewController.rootView = CleanPanel(delegate: self, model: model)
    refresh()

    window.contentViewController = viewController
    window.contentMinSize = viewController.view.intrinsicContentSize
  }

  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
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
    model.items = repository.unstagedChanges(showIgnored: true,
                                             recurseUntracked: false)
      .filter { $0.status.isCleanable }
      .sorted(byKeyPath: \.path.lastPathComponent)
      .map { .init(path: $0.gitPath, ignored: $0.status == .ignored) }
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
