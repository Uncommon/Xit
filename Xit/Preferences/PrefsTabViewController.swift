import Cocoa

final class PrefsTabViewController: NSTabViewController
{
  @IBOutlet weak var previewsTab: NSTabViewItem!
  var observer: NSObjectProtocol?
  var didInitialLoad = false
  
  override var selectedTabViewItemIndex: Int
  {
    didSet
    {
      guard let view = tabViewItems[selectedTabViewItemIndex].view,
            let window = view.window
      else { return }
      
      let minSize = view.fittingSize
      let contentRect = NSWindow.contentRect(forFrameRect: window.frame,
                                             styleMask: window.styleMask)
      let minRect = NSRect(origin: contentRect.origin, size: minSize)
      let newRect = minRect.union(contentRect)
      let newFrame = NSWindow.frameRect(forContentRect: newRect,
                                        styleMask: window.styleMask)
      
      window.setFrame(newFrame, display: true)
    }
  }
  
  override func viewWillAppear()
  {
    guard let window = tabView.window,
          observer == nil
    else { return }
    
    observer = NotificationCenter.default.addObserver(
        forName: NSWindow.didResignKeyNotification,
        object: window, queue: .main) {
      [weak self] _ in
      guard let items = self?.tabViewItems
      else { return }
      
      for item in items {
        guard let controller = item.viewController as? PreferencesSaver
        else { continue }
        
        controller.savePreferences()
      }
    }
    
    // For some reason the window initially appears too big
    if !didInitialLoad {
      didInitialLoad = true
      setInitialSize()
    }
  }
  
  func setInitialSize()
  {
    guard let view = tabViewItems[selectedTabViewItemIndex].view,
          let window = view.window
    else { return }
    
    var contentRect = NSWindow.contentRect(forFrameRect: window.frame,
                                           styleMask: window.styleMask)
    
    contentRect.size = view.fittingSize
    
    let newFrame = NSWindow.frameRect(forContentRect: contentRect,
                                      styleMask: window.styleMask)
    
    window.setFrame(newFrame, display: true)
  }
}
