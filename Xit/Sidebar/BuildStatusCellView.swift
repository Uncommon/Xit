import Cocoa

class BuildStatusCellView: NSTableCellView
{
  @IBOutlet var projectNameField: NSTextField!
  @IBOutlet var buildNumberField: NSTextField!
  @IBOutlet var progressBar: NSProgressIndicator!
  @IBOutlet var statusImage: NSImageView!
  
  override var backgroundStyle: NSView.BackgroundStyle
  {
    didSet
    {
      // The other fields get their color adjusted automatically. Maybe the
      // stack view gets in the way for this case.
      switch backgroundStyle {
        case .emphasized:
          projectNameField.textColor = NSColor.alternateSelectedControlTextColor
        case .normal:
          projectNameField.textColor = NSColor.controlTextColor
        default:
          break
      }
    }
  }
}
