import Cocoa

class BuildStatusCellView: NSTableCellView
{
  @IBOutlet var projectNameField: NSTextField!
  @IBOutlet var buildNumberField: NSTextField!
  @IBOutlet var progressBar: NSProgressIndicator!
  @IBOutlet var statusImage: NSImageView!
  
  override var backgroundStyle: NSBackgroundStyle
  {
    didSet
    {
      // The other fields get their color adjusted automatically. Maybe the
      // stack view gets in the way for this case.
      switch backgroundStyle {
        case .dark:
          projectNameField.textColor = NSColor.alternateSelectedControlTextColor
        case .light:
          projectNameField.textColor = NSColor.controlTextColor
        default:
          break
      }
    }
  }
}
