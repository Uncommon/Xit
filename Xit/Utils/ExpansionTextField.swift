import Cocoa

/// A text field that shows expansion tool tips when the text is truncated
class ExpansionTextField: NSTextField
{
  override init(frame frameRect: NSRect)
  {
    super.init(frame: frameRect)
    configureForTruncation()
  }

  required init?(coder: NSCoder)
  {
    super.init(coder: coder)
    configureForTruncation()
  }

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

  private func configureForTruncation()
  {
    usesSingleLineMode = true
    lineBreakMode = .byTruncatingTail
    allowsExpansionToolTips = true
  }
}
