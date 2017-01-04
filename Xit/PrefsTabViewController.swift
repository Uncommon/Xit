import Cocoa

class PrefsTabViewController: NSTabViewController
{
  @IBOutlet weak var previewsTab: NSTabViewItem!
  var observer: NSObjectProtocol?
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    // The generic document icon isn't available in Interface Builder.
    previewsTab.image = NSWorkspace.shared().icon(forFileType:
        NSFileTypeForHFSTypeCode(OSType(kGenericDocumentIcon)))
  }
  
  override func viewWillAppear()
  {
    guard let window = tabView.window,
          observer == nil
    else { return }
    
    observer = NotificationCenter.default.addObserver(
        forName: NSNotification.Name.NSWindowDidResignKey,
        object: window, queue: .main) {
      _ in
      for item in self.tabViewItems {
        guard let controller = item.viewController as? PreferencesSaver
        else { continue }
        
        controller.savePreferences()
      }
    }
  }
  
  deinit
  {
    observer.map { NotificationCenter.default.removeObserver($0) }
  }
}
