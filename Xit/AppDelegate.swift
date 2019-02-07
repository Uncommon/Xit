import AppKit

class AppDelegate: NSObject
{
  var openPanel: NSOpenPanel?
  
  var isTesting: Bool
  {
    return Bundle(identifier: "com.uncommonplace.XitTests") != nil
  }
  
  @IBOutlet var remoteSettingsSubmenu: NSMenu!
  
  override init()
  {
    super.init()
#if DEBUG
    UserDefaults.standard.register(defaults: ["WebKitDeveloperExtras": true])
#endif
  }
  
  @IBAction
  func openDocument(_ sender: Any?)
  {
    if let openPanel = openPanel {
      openPanel.makeKeyAndOrderFront(self)
      return
    }
    
    let newOpenPanel = NSOpenPanel()
    
    openPanel = newOpenPanel
    newOpenPanel.canChooseFiles = false
    newOpenPanel.canChooseDirectories = true
    newOpenPanel.delegate = self
    newOpenPanel.messageString = .openPrompt
    
    newOpenPanel.begin {
      (result) in
      if result == NSApplication.ModalResponse.OK {
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
        alert.beginSheetModal(for: window, completionHandler: nil)
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
    // The first NSDocumentController instance becomes the shared one.
    _ = XTDocumentController()
    
    let defaultsURL = Bundle.main.url(forResource: "Defaults",
                                      withExtension: "plist")!
    let defaults = NSDictionary(contentsOf: defaultsURL)!
    
    UserDefaults.standard.register(defaults: defaults as! [String: Any])
  }
  
  func applicationDidFinishLaunching(_ note: Notification)
  {
    if !isTesting {
      Services.shared.initializeServices()
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
