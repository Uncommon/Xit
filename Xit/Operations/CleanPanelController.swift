import Foundation
import SwiftUI
import Combine

final class CleanPanelController: NSWindowController
{
  class DataModel: ObservableObject
  {
    @Published var cleanFolders: Bool = false
    @Published var cleanIgnored: Bool = false
    @Published var cleanNonIgnored: Bool = true
    @Published var regex: String = ""
    @Published var items: [CleanableItem] = []
  }

  typealias Repository = FileStatusDetection & FileContents

  let repository: Repository
  let model = DataModel()

  init(repository: Repository)
  {
    let window = NSWindow(contentRect: .zero, styleMask: .docModalWindow,
                          backing: .buffered, defer: false)

    self.repository = repository
    super.init(window: window)

    refresh()

    let panel = CleanPanel(
          delegate: self,
          cleanFolders: .init(model, keyPath: \.cleanFolders),
          cleanIgnored: .init(model, keyPath: \.cleanIgnored),
          cleanNonIgnored: .init(model, keyPath: \.cleanNonIgnored),
          regex: .init(model, keyPath: \.regex),
          items: .init(model, keyPath: \.items))
      .environment(\.window, window)
    let viewController = NSHostingController(rootView: panel)

    window.contentViewController = viewController
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
