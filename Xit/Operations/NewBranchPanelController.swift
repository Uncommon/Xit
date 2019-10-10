import Cocoa

class NewBranchPanelController: SheetController
{
  var repository: Branching!
  var localBranchNames: [String] = []
  var remoteBranchNames: [String] = []

  @IBOutlet var branchNameField: NSTextField!
  @IBOutlet var startingPointField: NSTextField!
  @IBOutlet var checkOutCheckbox: NSButton!
  @IBOutlet var trackCheckbox: NSButton!
  @IBOutlet var createButton: NSButton!
  
  @ControlStringValue var branchName: String
  @ControlStringValue var startingPoint: String
  @ControlBoolValue var checkOutBranch: Bool
  @ControlBoolValue var trackStaringPoint: Bool

  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    $branchName = branchNameField
    $startingPoint = startingPointField
    $checkOutBranch = checkOutCheckbox
    $trackStaringPoint = trackCheckbox
  }
  
  func configure(branchName: String,
                 startingPoint: String,
                 repository: Branching)
  {
    self.branchName = branchName
    self.startingPoint = startingPoint
    
    localBranchNames = repository.localBranches.map { $0.shortName }
    remoteBranchNames = repository.remoteBranches.map { $0.shortName }
    
    updateCreateButton()
  }
  
  private func validateNames() -> Bool
  {
    if localBranchNames.contains(branchName) ||
       !GitReference.isValidName(RefPrefixes.heads +/ branchName) {
      return false
    }
    if !remoteBranchNames.contains(startingPoint) {
      return false
    }
    return true
  }
  
  private func updateCreateButton()
  {
    createButton.isEnabled = validateNames()
  }
}

extension NewBranchPanelController: NSControlTextEditingDelegate
{
}

extension NewBranchPanelController: NSTextFieldDelegate
{
  func controlTextDidChange(_ note: Notification)
  {
    if note.object as? NSTextField === startingPointField,
       let fieldEditor = note.userInfo?["NSFieldEditor"] as? NSText,
       !eventIsDelete() {
      fieldEditor.complete(nil)
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
  
  private func eventIsDelete() -> Bool
  {
    switch NSApp.currentEvent?.specialKey {
      case NSEvent.SpecialKey.delete,
           NSEvent.SpecialKey.backspace,
           NSEvent.SpecialKey.deleteCharacter,
           NSEvent.SpecialKey.deleteForward:
        return true
      default:
        return false
    }
  }
  
  private func completion(_ prefix: String) -> String?
  {
    return localBranchNames.first(withPrefix: prefix) ??
           remoteBranchNames.first(withPrefix: prefix)
  }
}

extension Array where Element == String
{
  func first(withPrefix prefix: String) -> String?
  {
    return first { $0.hasPrefix(prefix) }
  }
}
