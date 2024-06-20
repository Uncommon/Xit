import AppKit

@NSApplicationMain @MainActor
final class AppDelegate: NSObject
{
  var openPanel: NSOpenPanel?
  
  var isTesting: Bool
  { Bundle(identifier: "com.uncommonplace.XitTests") != nil }
  
  @IBOutlet var remoteSettingsSubmenu: NSMenu!
  
  override init()
  {
    super.init()
    #if DEBUG
    Testing.initialize()
    #endif
  }
  
  @IBAction
  func cloneRepository(_ sender: Any?)
  {
    if let openPanel = openPanel {
      openPanel.close()
      self.openPanel = nil
    }
    ClonePanelController.instance.showWindow(sender)
  }
  
  @IBAction
  func openDocument(_ sender: Any?)
  {
    if let openPanel = openPanel {
      openPanel.makeKeyAndOrderFront(self)
      return
    }
    if ClonePanelController.isShowingPanel {
      ClonePanelController.instance.close()
    }

    Task {
      let newOpenPanel = NSOpenPanel()

      openPanel = newOpenPanel
      newOpenPanel.canChooseFiles = false
      newOpenPanel.canChooseDirectories = true
      newOpenPanel.delegate = self
      newOpenPanel.messageString = .openPrompt

      if await newOpenPanel.begin() == .OK {
        for url in newOpenPanel.urls {
          NSDocumentController.shared.openDocument(
              withContentsOf: url,
              display: true) { (_, _, _) in }
        }
      }
      self.openPanel = nil
    }
  }
  
  @IBAction
  func showPreferences(_ sender: Any?)
  {
    PrefsWindowController.shared.window?
        .makeKeyAndOrderFront(nil)
  }
  
  @MainActor
  func activeWindowController() -> XTWindowController?
  {
    guard let controller = NSApp.mainWindow?.windowController
                           as? XTWindowController
    else { return nil }

    return controller
  }
  
  @objc
  func dismissOpenPanel()
  {
    if let panel: NSOpenPanel = NSApp.windows.firstOfType() {
      panel.close()
    }
  }
}

extension AppDelegate: NSMenuDelegate
{
  func menuNeedsUpdate(_ menu: NSMenu)
  {
    if menu == remoteSettingsSubmenu {
      activeWindowController()?.updateRemotesMenu(menu)
    }
  }
}

extension AppDelegate: NSOpenSavePanelDelegate
{
  func panel(_ sender: Any, validate url: URL) throws
  {
    let repoURL = url.appendingPathComponent(".git", isDirectory: true)
    
    if FileManager.default.fileExists(atPath: repoURL.path) {
      return
    }
    else {
      if let window = sender as? NSWindow {
        let alert = NSAlert()
        
        alert.messageString = .notARepository
        alert.beginSheetModal(for: window)
      }
      throw NSError(domain: NSCocoaErrorDomain,
                    code: CocoaError.featureUnsupported.rawValue)
    }
  }
}

extension AppDelegate: NSApplicationDelegate
{
  func applicationWillFinishLaunching(_ note: Notification)
  {
    git_libgit2_init()

    // The first NSDocumentController instance becomes the shared one.
    _ = XTDocumentController()
    
    let defaultsURL = Bundle.main.url(forResource: "Defaults",
                                      withExtension: "plist")!
    let defaults = NSDictionary(contentsOf: defaultsURL)!
    
    UserDefaults.standard.register(defaults: defaults as! [String: Any])
  }
  
  func applicationDidFinishLaunching(_ note: Notification)
  {
    if !isTesting && !UserDefaults.standard.bool(forKey: "noServices") {
      Services.xit.initializeServices(with: AccountsManager.xit)
    }
  }
  
  func applicationOpenUntitledFile(_ app: NSApplication) -> Bool
  {
    if !isTesting {
      openDocument(nil)
    }
    // Returning true prevents the app from opening an untitled document
    // on its own.
    return true
  }
}
