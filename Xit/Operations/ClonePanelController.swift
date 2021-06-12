import Foundation
import SwiftUI
import Combine

class CloneData: ObservableObject
{
  @Published var url: String = ""
  @Published var destination: String = ""
  @Published var name: String = ""
  @Published var branches: [String] = []
  @Published var selectedBranch: String = ""
  @Published var recurse: Bool = true
  
  @Published var inProgress: Bool = false

  enum CheckedValues: String, CaseIterable
  {
    case url, path
  }
  
  @Published var results: ProritizedResults<CheckedValues> = .init()
  
  var errorString: String?
  { results.firstError?.localizedDescription }
}

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

enum URLValidationError: Error
{
  case invalid
  case empty
  case cantAccess
  case gitError(RepoError)
  case unexpected
}

extension URLValidationError: LocalizedError
{
  var errorDescription: String?
  {
    switch self {
      case .invalid:
        return "Invalid URL"
      case .empty:
        return ""
      case .cantAccess:
        return "Unable to access repository"
      case .gitError(let error):
        return error.localizedDescription
      case .unexpected:
        return "Unexpected"
    }
  }
}

final class ClonePanelController: NSWindowController
{
  let data = CloneData()
  var urlObserver: AnyCancellable?
  var pathObserver: AnyCancellable?
  
  private static var currentController: ClonePanelController?
  
  static var isShowingPanel: Bool { currentController != nil }
  
  static var instance: ClonePanelController
  {
    if let panel = currentController {
      return panel
    }
    else {
      let controller = ClonePanelController.init()
      
      currentController = controller
      controller.window?.center()
      return controller
    }
  }
  
  @objc required dynamic init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
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
    
    // set up the progress panel
    
    do {
      try XTRepository.clone(from: sourceURL,
                             to: destURL,
                             branch: data.selectedBranch,
                             recurseSubmodules: data.recurse)
        
      XTDocumentController.shared
          .openDocument(withContentsOf: destURL, display: true,
                        completionHandler: { (_, _, _) in })
    }
    catch let error as RepoError {
      let alert = NSAlert()
      
      alert.messageText = error.localizedDescription
      alert.beginSheetModal(for: window!, completionHandler: nil)
    }
    catch {}
    close()
  }
  
  init()
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
    let viewController = NSHostingController(rootView: panel)

    super.init(window: window)
    window.title = "Clone a Repository"
    window.contentViewController = viewController
    window.collectionBehavior = [.transient, .participatesInCycle,
                                 .fullScreenAuxiliary]
    window.standardWindowButton(.zoomButton)?.isEnabled = false
    window.center()
    window.delegate = self
    
    self.urlObserver = data.$url
      .debounce(afterInvalidating: data, keyPath: \.results.url)
      .sink { [self] (url) in
        data.inProgress = true
        data.results.url = nil
        data.branches = []
        DispatchQueue.global(qos: .userInitiated).async {
          let result = Self.readURL(url)
          
          DispatchQueue.main.async {
            data.inProgress = false
            switch result {
              case .success((let name, let branches, let selectedBranch)):
                data.name = name
                data.results.name = nil
                data.branches = branches
                data.selectedBranch = selectedBranch
                data.results.url = result
              case .failure(.empty):
                data.results.url = nil
              default:
                data.results.url = result
            }
            if case .failure(.empty) = result {
              data.results.url = nil
            }
            else {
              data.results.url = result
            }
          }
        }
      }
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
  
  static func readURL(_ newURL: String)
    -> Result<(name: String, branches: [String], selectedBranch: String),
              URLValidationError>
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
