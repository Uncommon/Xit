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
  @Published var urlValid: Bool = false
  @Published var error: String?
}

class ClonePanelController: NSWindowController
{
  let data = CloneData()
  var urlObserver: AnyCancellable?
  
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
//    do {
//      var options = git_clone_options.defaultOptions()
//      let checkoutBranch = "main" // get the selected branch
//      
//      try checkoutBranch.withCString { branchPtr in
//        options.bare = 0
//        options.checkout_branch = branchPtr
//        // fetch progress callbacks
//
//        let repo = try OpaquePointer.from {
//          git_clone(&$0, url, destination +/ name, &options)
//        }
//        
//        // open the repo
//      }
//      
//    }
//    catch _ as RepoError {
//      // error alert
//    }
//    catch {}
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
    window.title = "Clone"
    window.contentViewController = viewController
    window.collectionBehavior = [.transient, .participatesInCycle,
                                 .fullScreenAuxiliary]
    window.standardWindowButton(.zoomButton)?.isEnabled = false
    window.center()
    window.delegate = self
    
    self.urlObserver = data.$url.debounce(for: 0.5, scheduler: DispatchQueue.main)
                                .sink {
      self.readURL($0)
    }
  }
  
  func validate(url: URL) -> Bool
  {
    guard let scheme = url.scheme,
          scheme == "file" || url.host != nil,
          !url.path.isEmpty
    else { return false }
    
    return true
  }
  
  func readURL(_ newURL: String)
  {
    data.inProgress = true
    defer { data.inProgress = false }
    data.urlValid = false
    data.branches = []
    data.error = nil
    
    guard let url = URL(string: newURL),
          validate(url: url),
          let remote = GitRemote(url: url)
    else {
      data.error = newURL.isEmpty ? nil : "Invalid URL"
      return
    }
    
    data.name = url.path.lastPathComponent.deletingPathExtension

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

      data.branches = heads.compactMap { head in
        head.name.hasPrefix(RefPrefixes.heads) ?
            head.name.droppingPrefix(RefPrefixes.heads) : nil
      }
      if let branch = [defaultBranch, "main", "master"]
          .compactMap({ $0 })
          .first(where: { data.branches.contains($0) }) {
        data.selectedBranch = branch
      }
      else {
        data.selectedBranch = ""
      }
    }
    catch let error as RepoError {
      switch error {
        case .gitError(let code) where code == GIT_ERROR.rawValue:
          data.error = "Unable to access repository"
        default:
          data.error = error.localizedDescription
      }
      return
    }
    catch {
      return
    }

    data.urlValid = true
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
