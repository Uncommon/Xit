import AppKit

class AppDelegate: NSObject
{
  var openPanel: NSOpenPanel?
  
  var isTesting: Bool
  {
    return Bundle(identifier:"com.uncommonplace.XitTests") != nil
  }
  
  @IBOutlet var remoteSettingsSubmenu: NSMenu!
  
  override init()
  {
    super.init()
#if DEBUG
    UserDefaults.standard.register(defaults: ["WebKitDeveloperExtras": true])
#endif
  }
  
  @IBAction func openDocument(_ sender: Any?)
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
    newOpenPanel.message = "Open a directory that contains a Git repository"
    
    newOpenPanel.begin {
      (result) in
      if result == NSFileHandlingPanelOKButton {
        for url in newOpenPanel.urls {
          NSDocumentController.shared().openDocument(
              withContentsOf: url,
              display: true,
              completionHandler: { (_, _, _) in })
        }
      }
      self.openPanel = nil
    }
  }
  
  @IBAction func showPreferences(_ sender: Any?)
  {
    XTPrefsWindowController.sharedPrefsController.window?
        .makeKeyAndOrderFront(nil)
  }
  
  func activeWindowController() -> XTWindowController?
  {
    guard let controller = NSApp.mainWindow?.windowController
                           as? XTWindowController
    else { return nil }

    return controller
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
    
    if FileManager.default.fileExists(atPath:repoURL.path) {
      return
    }
    else {
      if let window = sender as? NSWindow {
        let alert = NSAlert()
        
        alert.messageText = "That folder does not contain a Git repository."
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
  }
  
  func applicationDidFinishLaunching(_ note: Notification)
  {
    if !isTesting {
      XTServices.services.initializeServices()
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
