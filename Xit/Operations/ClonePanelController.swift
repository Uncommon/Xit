import Foundation
import SwiftUI
import Combine

enum PathValidationError: Error
{
  case noName
  case alreadyExists
  case notWritable
  case unwindFailure
}

extension PathValidationError: LocalizedError
{
  var errorDescription: String?
  {
    switch self {
      case .noName:
        return "Folder name needed"
      case .alreadyExists:
        return "Directory already exists"
      case .notWritable:
        return "Directory not writable"
      case .unwindFailure:
        return "Can't access directory"
    }
  }
}

struct WindowEnvironmentKey: EnvironmentKey
{
  static let defaultValue: NSWindow = NSApp.mainWindow ?? NSWindow()
}

extension EnvironmentValues
{
  var window: NSWindow
  {
    get { self[WindowEnvironmentKey.self] }
    set { self[WindowEnvironmentKey.self] = newValue }
  }
}

final class ClonePanelController: NSWindowController
{
  let cloner: Cloning
  let data = CloneData(readURL: ClonePanelController.readURL(_:))
  var urlObserver: AnyCancellable?
  var pathObserver: AnyCancellable?
  
  var progressPanel: ProgressPanelController?
  
  private static var currentController: ClonePanelController?
  
  static var isShowingPanel: Bool { currentController != nil }
  
  static var instance: ClonePanelController
  {
    if let panel = currentController {
      return panel
    }
    else {
      let controller = Self.init(cloner: GitCloner())
      
      currentController = controller
      controller.window?.center()
      return controller
    }
  }
  
  @objc required dynamic init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  func showProgressPanel(progress: ObservableProgress)
  {
    guard let window = self.window
    else { return }
    
    progressPanel = .init(model: progress) {
      guard let window = self.window,
            let progressWindow = self.progressPanel?.window
      else { return }
      progress.canceled = true
      window.endSheet(progressWindow)
      self.progressPanel = nil
    }
    
    guard let progressWindow = progressPanel?.window
    else { return }
    
    window.beginSheet(progressWindow, completionHandler: nil)
  }
  
  @IBAction
  func clone(_ sender: Any?)
  {
    guard let sourceURL = URL(string: data.url)
    else {
      return
    }
    let destURL = URL(fileURLWithPath: data.destination +/ data.name,
                      isDirectory: true)
    
    let progress = ObservableProgress(message: "Fetching...")
    let callbacks = RemoteCallbacks(
          passwordBlock: nil, // use from PasswordOpController
          downloadProgress:  progress.progressCallback(_:),
          sidebandMessage: progress.messageCallback(_:))
    
    showProgressPanel(progress: progress)
    
    DispatchQueue.global(qos: .userInitiated).async {
      [self] in
      let result = Result(catching: {
        try cloner.clone(from: sourceURL,
                         to: destURL,
                         branch: data.selectedBranch,
                         recurseSubmodules: data.recurse,
                         callbacks: callbacks)
      })
      
      DispatchQueue.main.async {
        switch result {
          case .success(let repository):
            guard repository != nil
            else { break }
            XTDocumentController.shared
                .openDocument(withContentsOf: destURL, display: true,
                              completionHandler: { (_, _, _) in })
            close()
          case .failure(let error):
            let alert = NSAlert()
            
            alert.messageText = error.localizedDescription
            alert.beginSheetModal(for: window!, completionHandler: {
              _ in close()
            })
        }
      }
    }
  }
  
  init(cloner: Cloning)
  {
    let window = NSWindow(contentRect: .init(origin: .zero,
                                             size: .init(width: 300,
                                                         height: 100)),
                          styleMask: [.closable, .resizable, .titled],
                          backing: .buffered, defer: false)
    let panel = ClonePanel(data: data,
                           close: { window.close() },
                           // Avoid capturing self yet
                           clone: { window.tryToPerform(#selector(Self.clone(_:)),
                                                        with: nil) })
                .environment(\.window, window)
    let viewController = NSHostingController(rootView: panel)

    self.cloner = cloner
    
    super.init(window: window)
    window.title = "Clone a Repository"
    window.contentViewController = viewController
    window.collectionBehavior = [.transient, .participatesInCycle,
                                 .fullScreenAuxiliary]
    window.standardWindowButton(.zoomButton)?.isEnabled = false
    window.center()
    window.delegate = self
    
    self.pathObserver = data.$destination.combineLatest(data.$name)
      .debounce(afterInvalidating: data, keyPath: \.results.path)
      .sink { [self] _ in
        data.results.path = validatePath()
      }

    data.destination = defaultDestination()
  }
  
  func defaultDestination() -> String
  {
    let manager = FileManager.default
    let types: [FileManager.SearchPathDirectory] =
      [.developerDirectory, .documentDirectory, .userDirectory]
    
    return types.firstResult {
      manager.urls(for: $0, in: .userDomainMask).first
    }?.path ?? "/"
  }
  
  // The advantage of Result<> over throws is you can specify the error type.
  func validatePath() -> Result<Void, PathValidationError>
  {
    guard !data.name.isEmpty
    else {
      return .failure(.noName)
    }
    
    let manager = FileManager.default
    let fullPath = data.destination +/ data.name
    
    guard !manager.fileExists(atPath: fullPath)
    else {
      return .failure(.alreadyExists)
    }
    
    var path = data.destination
    
    repeat {
      var isDirectory: ObjCBool = false
      
      if manager.fileExists(atPath: path,
                            isDirectory: &isDirectory) &&
          isDirectory.boolValue {
        if !manager.isWritableFile(atPath: path.withSuffix("/")) {
          return .failure(.notWritable)
        }
        return .success(())
      }
      path = path.deletingLastPathComponent
    } while !path.isEmpty && path != "/"
    
    return .failure(.unwindFailure)
  }
  
  static func validate(url: URL) -> Bool
  {
    guard let scheme = url.scheme,
          scheme == "file" || url.host != nil,
          !url.path.isEmpty
    else { return false }
    
    return true
  }
  
  static func readURL(_ newURL: String) -> CloneData.URLResult
  {
    guard let url = URL(string: newURL)
    else { return .failure(.empty) }
    guard validate(url: url),
          let remote = GitRemote(url: url)
    else { return .failure(.invalid) }
    let name: String
    let branches: [String]
    let selectedBranch: String
    
    name = url.path.lastPathComponent.deletingPathExtension

    do {
      // May need a password callback depending on the host
      let (heads, defaultBranchRef) = try
        remote.withConnection(direction: .fetch,
                              callbacks: .init(),
                              action: {
        (try $0.referenceAdvertisements(), $0.defaultBranch)
      })
      let defaultBranch = defaultBranchRef.map {
        $0.droppingPrefix(RefPrefixes.heads)
      }

      branches = heads.compactMap { head in
        head.name.hasPrefix(RefPrefixes.heads) ?
            head.name.droppingPrefix(RefPrefixes.heads) : nil
      }
      if let branch = [defaultBranch, "main", "master"]
          .compactMap({ $0 })
          .first(where: { branches.contains($0) }) {
        selectedBranch = branch
      }
      else {
        selectedBranch = branches.first ?? ""
      }
    }
    catch let error as RepoError {
      switch error {
        case .gitError(let code) where code == GIT_ERROR.rawValue:
          return .failure(.cantAccess)
        default:
          return .failure(.gitError(error))
      }
    }
    catch {
      return .failure(.unexpected)
    }

    return .success((name: name,
                     branches: branches,
                     selectedBranch: selectedBranch))
  }
}

extension ClonePanelController: NSWindowDelegate
{
  func windowWillClose(_ notification: Notification)
  {
    guard let window = notification.object as? NSWindow
    else { return }
    
    if window == Self.currentController?.window {
      Self.currentController = nil
    }
  }
}
