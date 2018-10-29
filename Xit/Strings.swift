import Foundation

// swiftlint:disable line_length

prefix operator ›

prefix func ›(string: StringLiteralType) -> UIString
{
  return UIString(rawValue: string)
}

struct UIString: RawRepresentable
{
  let rawValue: String
  
  init(rawValue: String)
  {
    self.rawValue = rawValue
  }
  
  init(error: NSError)
  {
    rawValue = error.localizedDescription
  }
  
  static let multipleItemsSelected = ›"Multiple items selected"
  static let blameNotAvailable = ›"Blame not available"
  static let noSelection = ›"No selection"
  
  static let unstage = ›"Unstage"
  static let stage = ›"Stage"
  static let discard = ›"Discard"
  
  static let cantApplyHunk = ›"This hunk cannot be applied"
  static let whitespaceChangesHidden = ›"Whitespace changes are hidden"
  static let binaryFile = ›"This is a binary file"
  static let noChanges = ›"No changes for this selection"
  static let noStagedChanges = ›"No staged changes for this selection"
  static let noUnstagedChanges = ›"No unstaged changes for this selection"
  
  static let apply = ›"Apply"
  static let delete = ›"Delete"
  static let drop = ›"Drop"
  static let pop = ›"Pop"
  static let revert = ›"Revert"
  static let cancel = ›"Cancel"
  
  static let showSidebar = ›"Show Sidebar"
  static let hideSidebar = ›"Hide Sidebar"
  
  static let confirmDeleteAccount = ›"Are you sure you want to delete the selected account?"
  static let confirmRevertMultiple = ›"Revert changes to the selected files?"
  static let confirmRevertFormat = "Are you sure you want to revert changes to %@?"
  
  static func confirmRevert(_ name: String) -> UIString
  {
    return UIString(rawValue: String(format: UIString.confirmRevertFormat, name))
  }
  
  static let newFileDeleted = ›"The new file will be deleted."
  
  static let noStashes = ›"Repository has no stashes."
  static let confirmPop = ›"Apply the most recent stash, and then delete it?"
  static let confirmApply = ›"Apply the most recent stash, without deleting it?"
  static let confirmStashDelete = ›"Delete the most recent stash?"
  
  static let keychainInvalidURL = ›"""
      The password could not be saved to the keychain because \
      the URL is not valid.
      """
  static let keychainError = ›"""
      The password could not be saved to the keychain because \
      an unexpected error occurred.
      """
  
  static let cantSavePassword = ›"The password could not be saved."
  static let invalidName = ›"The name is not valid."
  static let invalidURL = ›"The URL is not valid."
  static let unexpectedError = ›"An unexpected error occurred."
}

extension NSAlert
{
  var messageString: UIString
  {
    get { return UIString(rawValue: messageText) }
    set { messageText = newValue.rawValue }
  }
  var informativeString: UIString
  {
    get { return UIString(rawValue: informativeText) }
    set { informativeText = newValue.rawValue }
  }
  
  func addButton(withString title: UIString)
  {
    addButton(withTitle: title.rawValue)
  }
}

extension NSMenuItem
{
  var titleString: UIString
  {
    get { return UIString(rawValue: title) }
    set { title = newValue.rawValue }
  }
}
