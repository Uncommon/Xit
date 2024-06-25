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

final class ClonePanelController: NSWindowController
{
  let cloner: any Cloning
  let data = CloneData(readURL: ClonePanelController.readURL(_:))
  let presentingModel = PresentingModel()
  let progressPublisher = RemoteProgressPublisher()
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
      let controller = Self.init(cloner: GitCloner())
      
      currentController = controller
      controller.window?.center()
      return controller
    }
  }
  
  init(cloner: any Cloning)
  {
    self.cloner = cloner

    let window = NSWindow(contentRect: .init(origin: .zero,
                                             size: .init(width: 300,
                                                         height: 100)),
                          styleMask: [.closable, .resizable, .titled],
                          backing: .buffered, defer: false)
    
    super.init(window: window)

    let panel = ClonePanel(data: data,
                           close: { window.close() },
                           clone: { self.clone() })
                .environment(\.window, window)
    let host = ProgressHost(model: presentingModel,
                            message: "Cloning...",
                            publisher: progressPublisher.subject
                              .eraseToAnyPublisher(),
                            content: { panel })
    let viewController = NSHostingController(rootView: host)

    window.titleString = .cloneTitle
    window.contentViewController = viewController
    window.standardWindowButton(.zoomButton)?.isEnabled = false
    window.center()
    window.delegate = self
    
    self.pathObserver = data.$destination.combineLatest(data.$name)
      .debounce(afterInvalidating: data, keyPath: \.results.path)
      .sink { [self] _ in
        data.results.path = validatePath()
      }

    data.destination = defaultDestination()
    
    progressPublisher.setPasswordBlock {
      let panel = PasswordPanelController()
      guard let url = URL(string: self.data.url)
      else { return nil }
      
      return panel.getPassword(
          parentWindow: window,
          host: url.host ?? "",
          path: url.path,
          port: UInt16(url.port ?? url.defaultPort))
    }
  }

  @objc required dynamic init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  func clone()
  {
    guard let sourceURL = URL(string: data.url)
    else {
      return
    }
    let destURL = URL(fileURLWithPath: data.destination +/ data.name,
                      isDirectory: true)
    
    presentingModel.showSheet = true

    let selectedBranch = data.selectedBranch
    let recurse = data.recurse

    DispatchQueue.global(qos: .userInitiated).async {
      [self] in
      let result = Result(catching: {
        try cloner.clone(from: sourceURL,
                         to: destURL,
                         branch: selectedBranch,
                         recurseSubmodules: recurse,
                         publisher: progressPublisher)
      })
      
      DispatchQueue.main.async {
        self.presentingModel.showSheet = false
        switch result {
          case .success(let repository):
            guard repository != nil
            else { break }
            XTDocumentController.shared
                .openDocument(withContentsOf: destURL, display: true,
                              completionHandler: { (_, _, _) in })
            self.close()
          case .failure(let error):
            guard let window = self.window
            else { break }
            let alert = NSAlert()
            
            alert.messageText = error.localizedDescription
            alert.beginSheetModal(for: window)
        }
      }
    }
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
  
  nonisolated
  static func validate(url: URL) -> Bool
  {
    guard let scheme = url.scheme,
          scheme == "file" || url.host != nil,
          !url.path.isEmpty
    else { return false }
    
    return true
  }

  nonisolated
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
    let noPassword: () -> (String, String)? = { nil }
    
    name = url.path.lastPathComponent.deletingPathExtension

    do {
      let (heads, defaultBranchRef) = try
        remote.withConnection(direction: .fetch,
                              callbacks: .init(passwordBlock: noPassword),
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
        case .gitError(let code, _) where code == GIT_ERROR.rawValue:
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
    // The password block captures self because it needs the latest URL
    progressPublisher.setPasswordBlock(nil)
  }
}
