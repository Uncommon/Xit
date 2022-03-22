import Cocoa

final class NewBranchPanelController: SheetController
{
  var localBranchNames: [String] = []
  var remoteBranchNames: [String] = []
  var startingPointEditor = FullReplacementTextView()
  
  private var isCompleting = false

  @IBOutlet var branchNameField: NSTextField!
  @IBOutlet var startingPointField: NSTextField!
  @IBOutlet var checkOutCheckbox: NSButton!
  @IBOutlet var trackCheckbox: NSButton!
  @IBOutlet var createButton: NSButton!
  
  @ControlStringValue var branchName: String
  @ControlStringValue var startingPoint: String
  @ControlBoolValue var checkOutBranch: Bool
  @ControlBoolValue var trackStartingPoint: Bool

  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    $branchName = branchNameField
    $startingPoint = startingPointField
    $checkOutBranch = checkOutCheckbox
    $trackStartingPoint = trackCheckbox
    
    startingPointEditor.isFieldEditor = true
  }
  
  func configure(branchName: String,
                 startingPoint: String,
                 repository: any Branching)
  {
    self.branchName = branchName
    self.startingPoint = startingPoint
    
    localBranchNames = repository.localBranches.map { $0.shortName }
    remoteBranchNames = repository.remoteBranches.map { $0.shortName }
    
    updateCreateButton()
  }
  
  private func validateNames() -> Bool
  {
    let branchName = self.branchName

    if branchName.isEmpty ||
       localBranchNames.contains(branchName) ||
       !GitReference.isValidName(RefPrefixes.heads +/ branchName) {
      return false
    }
    
    let startingPoint = self.startingPoint

    if !startingPoint.isEmpty &&
       !(localBranchNames.contains(startingPoint) ||
         remoteBranchNames.contains(startingPoint)) {
      return false
    }
    return true
  }
  
  private func updateCreateButton()
  {
    createButton.isEnabled = validateNames()
  }
}

extension NewBranchPanelController: NSTextFieldDelegate
{
  func controlTextDidChange(_ note: Notification)
  {
    if !isCompleting && note.object as? NSTextField === startingPointField,
       let fieldEditor = note.userInfo?["NSFieldEditor"] as? NSText,
       !NSApp.currentEventIsDelete {
      isCompleting = true
      fieldEditor.complete(nil)
      isCompleting = false
    }
    
    updateCreateButton()
  }
  
  func control(_ control: NSControl,
               textView: NSTextView,
               completions words: [String],
               forPartialWordRange charRange: NSRange,
               indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]
  {
    let text = textView.string
    guard let range = Range(charRange, in: text)
    else { return [] }
    let typedText = text[range]
    
    return localBranchNames.filter { $0.hasPrefix(typedText) } +
           remoteBranchNames.filter { $0.hasPrefix(typedText) }
  }
}

extension NewBranchPanelController: NSWindowDelegate
{
  func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any?
  {
    if let clientField = client as? NSTextField,
       clientField === startingPointField {
      return startingPointEditor
    }
    else {
      return nil
    }
  }
}

/// A text view that always uses the full text for typing completion
class FullReplacementTextView: NSTextView
{
  override var rangeForUserCompletion: NSRange
  { self.string.fullNSRange }
}
