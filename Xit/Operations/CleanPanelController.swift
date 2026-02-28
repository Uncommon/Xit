import Foundation
import SwiftUI
import Combine
import XitGit

final class CleanPanelController: NSWindowController
{
  typealias Repository = FileStatusDetection & FileContents

  let repository: any Repository
  let model = CleanData()

  private var folderSubscriber: AnyCancellable?

  init(repository: any Repository)
  {
    self.repository = repository
    
    // Initially empty window because CleanPanel needs a reference to self
    let window = NSWindow()
    
    super.init(window: window)
    
    let panel = CleanPanel(delegate: self, model: model,
                           fileURLForPath: { repository.fileURL($0) })
    let viewController = NSHostingController(rootView: panel)
    
    window.contentViewController = viewController
    // Unlike NSWindow(contentViewController:), setting the content view
    // controller afterwards doesn't make the window resizable.
    window.styleMask = [.docModalWindow, .resizable]
    window.contentMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                            height: .greatestFiniteMagnitude)
    refresh()

    folderSubscriber = model.$folderMode.sink {
      self.refresh(folderMode: $0)
    }

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
      .sorted { $0.path.lastPathComponent <~ $1.path.lastPathComponent }
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
        do {
          try fileManager.removeItem(at: url)
        }
        catch let error {
          throw CleanPanel.CleanError(path: path, orginal: error)
        }
      }
    }
  }
  
  func show(_ files: [String])
  {
    let urls = files.map { repository.fileURL($0) }
    
    NSWorkspace.shared.activateFileViewerSelecting(urls)
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
