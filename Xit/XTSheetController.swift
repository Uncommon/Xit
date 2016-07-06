import Cocoa

public class XTSheetController: NSWindowController {
  
  func end(code: NSModalResponse)
  {
    window!.sheetParent?.endSheet(window!, returnCode: code)
  }
  
  @IBAction func accept(sender: AnyObject)
  {
    end(NSModalResponseOK)
  }
  
  @IBAction func cancel(sender: AnyObject)
  {
    end(NSModalResponseCancel)
  }
  
  /// Resets all fields and controls for a new session.
  func resetFields()
  {
  }
  
  class func controller() -> Self
  {
    let result = self.init(windowNibName: String(self))
    
    _ = result.window  // force the nib to load
    return result
  }
}
