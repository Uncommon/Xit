import Cocoa

final class TagPanelController: SheetController
{
  @IBOutlet weak var commitMessageLabel: NSTextField!
  @IBOutlet weak var tagNameField: NSTextField!
  @IBOutlet weak var lightweightRadio: NSButton!
  @IBOutlet weak var annotatedRadio: NSButton!
  @IBOutlet weak var messageField: NSTextView!
  @IBOutlet weak var signatureLabel: NSTextField!
  @IBOutlet weak var tagButton: NSButton!
  
  @ControlStringValue var commitMessage: String
  @ControlStringValue var tagName: String
  @ControlStringValue var signature: String
  @TextViewString var message: String
  
  var lightweight: Bool
  {
    get
    { lightweightRadio.boolValue }
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
  
  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    $commitMessage = commitMessageLabel
    $tagName = tagNameField
    $signature = signatureLabel
    $message = messageField
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
    tagButton.isEnabled = GitReference.isValidName("refs/tags/\(tagName)")
  }
}
