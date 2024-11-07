import Cocoa

final class RenameBranchPanelController: SheetController
{
  @IBOutlet weak var promptLabel: NSTextField!
  @IBOutlet weak var textField: NSTextField!
  
  var branchName: LocalBranchRefName?
  {
    get
    { .named(textField.stringValue) }
    set
    {
      guard let newValue
      else { preconditionFailure("shouldn't set nil branch") }
      promptLabel.uiStringValue = .renamePrompt(newValue.name)
      textField.stringValue = newValue.name
    }
  }
}

extension RenameBranchPanelController: NSTextFieldDelegate
{
  func controlTextDidChange(_ obj: Notification)
  {
    acceptButton!.isEnabled = GitReference.isValidName(
        RefPrefixes.heads +/ textField.stringValue)
  }
}
