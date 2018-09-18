import Cocoa

public class SheetController: NSWindowController
{
  func end(_ code: NSApplication.ModalResponse)
  {
    window!.sheetParent?.endSheet(window!, returnCode: code)
  }
  
  @IBAction func accept(_ sender: AnyObject)
  {
    end(.OK)
  }
  
  @IBAction func cancel(_ sender: AnyObject)
  {
    end(.cancel)
  }
  
  /// Resets all fields and controls for a new session.
  func resetFields()
  {
  }
  
  class func controller() -> Self
  {
    let result = self.init(windowNibName: String(describing: self))
    
    _ = result.window  // force the nib to load
    return result
  }
}
