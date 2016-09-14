import Cocoa

/// Toolbar item that disables itself during repository writing operations.
class XTWritingToolbarItem: NSToolbarItem {

  override func observeValueForKeyPath(keyPath: String?,
                                       ofObject object: AnyObject?,
                                       change: [String : AnyObject]?,
                                       context: UnsafeMutablePointer<Void>)
  {
    guard let keyPath = keyPath,
          let change = change
    else { return }
    
    if keyPath == "isWriting" {
      let writing = change[NSKeyValueChangeNewKey]?.boolValue ?? true

      dispatch_async(dispatch_get_main_queue()) {
        [weak self] in
        self?.enabled = !writing
        self?.view?.needsDisplay = true
      }
    }
  }
}
