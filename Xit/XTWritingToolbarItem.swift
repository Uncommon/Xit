import Cocoa

/// Toolbar item that disables itself during repository writing operations.
class XTWritingToolbarItem: NSToolbarItem {

  override func observeValue(forKeyPath keyPath: String?,
                             of object: Any?,
                             change: [NSKeyValueChangeKey : Any]?,
                             context: UnsafeMutableRawPointer?)
  {
    guard let keyPath = keyPath,
          let change = change
    else { return }
    
    if keyPath == "isWriting" {
      let writing = (change[NSKeyValueChangeKey.newKey] as AnyObject).boolValue ?? true

      DispatchQueue.main.async {
        [weak self] in
        self?.isEnabled = !writing
        self?.view?.needsDisplay = true
      }
    }
  }
}
