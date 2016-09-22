import Cocoa

class XTDocumentController: NSDocumentController
{
  // This can get triggered by clicking the new tab button in a tabbed window.
  override func newDocument(_ sender: Any?)
  {
    _ = NSApp.delegate?.perform(#selector(openDocument(_:)), with: sender)
  }
}
