import Foundation
import SwiftUI

class CloneData: ObservableObject
{
  @Published var url: String = ""
  @Published var destination: String = ""
  @Published var name: String = ""
  @Published var branches: [String] = []
  @Published var recurse: Bool = true
}

class ClonePanelController: NSWindowController
{
  let data = CloneData()
  
  var url: String = ""
  var destination: String = ""
  var name: String = ""
  var branches: [String] = []
  var recurse: Bool = true
  
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
  
  func clone()
  {
    do {
      var options = git_clone_options.defaultOptions()
      let checkoutBranch = "main" // get the selected branch
      
      try checkoutBranch.withCString { branchPtr in
        options.bare = 0
        options.checkout_branch = branchPtr
        // fetch progress callbacks

        let repo = try OpaquePointer.from {
          git_clone(&$0, url, destination +/ name, &options)
        }
        
        // open the repo
      }
      
    }
    catch let error as RepoError {
      // error alert
    }
    catch {}
  }
  
  init()
  {
    let window = NSWindow(contentRect: .init(origin: .zero,
                                             size: .init(width: 300,
                                                         height: 100)),
                          styleMask: [.closable, .resizable, .titled],
                          backing: .buffered, defer: false)
    let viewController = NSHostingController(rootView: ClonePanel(data: data))

    super.init(window: window)
    window.title = "Clone"
    window.contentViewController = viewController
    window.collectionBehavior = [.transient, .participatesInCycle,
                                 .fullScreenAuxiliary]
    window.standardWindowButton(.zoomButton)?.isEnabled = false
    window.center()
    window.delegate = self
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
