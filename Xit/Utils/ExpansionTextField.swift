import Cocoa

/// A text field that shows expansion tool tips when the text is truncated
class ExpansionTextField: NSTextField
{
  override var frame: NSRect
  {
    didSet
    {
      if isTruncated {
        toolTip = stringValue
      }
      else {
        toolTip = nil
      }
    }
  }
}
