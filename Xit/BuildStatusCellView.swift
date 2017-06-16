import Cocoa

class BuildStatusCellView: NSTableCellView
{
  @IBOutlet var projectNameField: NSTextField!
  @IBOutlet var buildNumberField: NSTextField!
  @IBOutlet var progressBar: NSProgressIndicator!
  @IBOutlet var statusImage: NSImageView!
}
