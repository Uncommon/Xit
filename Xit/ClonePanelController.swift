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

class ClonePanelController: NSHostingController<ClonePanel>
{
  let data = CloneData()
  
  var url: String = ""
  var destination: String = ""
  var name: String = ""
  var branches: [String] = []
  var recurse: Bool = true
  
  private static weak var currentPanel: NSWindow?
  
  static var panel: NSWindow
  {
    if let panel = currentPanel {
      return panel
    }
    else {
      let panel = createPanel()
      
      currentPanel = panel
      panel.center()
      return panel
    }
  }
  
  init()
  {
    super.init(rootView: ClonePanel(data: data))
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
  
  static func createPanel() -> NSWindow
  {
    let window = NSWindow(contentRect: .init(origin: .zero,
                                             size: .init(width: 300,
                                                         height: 100)),
                          styleMask: [.closable, .resizable, .titled],
                          backing: .buffered, defer: false)
    let controller = ClonePanelController()

    window.title = "Clone"
    window.contentViewController = controller
    window.center()
    return window
  }
}
