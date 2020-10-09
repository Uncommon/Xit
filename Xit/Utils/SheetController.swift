import Cocoa

public class SheetController: NSWindowController
{
  enum Mode
  {
    case edit
    case create(actionString: UIString?)
    
    var buttonTitle: UIString
    {
      switch self {
        case .edit:
          return .ok
        case .create(let title):
          return title ?? .create
      }
    }
  }

  @IBOutlet weak var acceptButton: NSButton?
  
  func setMode(_ mode: Mode)
  {
    acceptButton?.uiStringValue = mode.buttonTitle
  }

  func end(_ code: NSApplication.ModalResponse)
  {
    window!.sheetParent?.endSheet(window!, returnCode: code)
  }
  
  @IBAction
  func accept(_ sender: AnyObject)
  {
    end(.OK)
  }
  
  @IBAction
  func cancel(_ sender: AnyObject)
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
