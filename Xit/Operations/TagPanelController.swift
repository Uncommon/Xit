import Cocoa

class TagPanelController: SheetController
{
  @IBOutlet weak var commitMessageLabel: NSTextField!
  @IBOutlet weak var tagNameField: NSTextField!
  @IBOutlet weak var lightweightRadio: NSButton!
  @IBOutlet weak var annotatedRadio: NSButton!
  @IBOutlet weak var messageField: NSTextView!
  @IBOutlet weak var signatureLabel: NSTextField!
  @IBOutlet weak var tagButton: NSButton!
  
  var commitMessage: String
  {
    get { return commitMessageLabel.stringValue }
    set { commitMessageLabel.stringValue = newValue }
  }
  var tagName: String { return tagNameField.stringValue }
  var signature: String
  {
    get { return signatureLabel.stringValue }
    set { signatureLabel.stringValue = newValue }
  }
  var message: String { return messageField.string }
  
  var lightweight: Bool
  {
    get
    {
      return lightweightRadio.boolValue
    }
    set
    {
      let textColor = newValue ? NSColor.disabledControlTextColor
                               : NSColor.textColor
      
      lightweightRadio.boolValue = newValue
      annotatedRadio.boolValue = !newValue
      signatureLabel.textColor = textColor
      messageField.enclosingScrollView?.borderType = newValue ? .noBorder
                                                              : .bezelBorder
      messageField.isEditable = !newValue
      messageField.textColor = textColor
    }
  }
  
  @IBAction
  func tagTypeChanged(_ sender: NSButton)
  {
    lightweight = sender == lightweightRadio
  }
}

extension TagPanelController: NSTextFieldDelegate
{
  func controlTextDidChange(_ obj: Notification)
  {
    tagButton.isEnabled = XTRefFormatter.isValidRefString("refs/tags/\(tagName)")
  }
}
