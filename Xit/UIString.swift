import Foundation
import SwiftUI

// swiftlint:disable line_length

prefix operator ›

prefix func ›(string: StringLiteralType) -> UIString
{
  return UIString(rawValue: string)
}

/// Contains a string that is specifically for display in the user interface.
struct UIString: RawRepresentable
{
  let rawValue: String
  
  init(rawValue: String)
  {
    self.rawValue = rawValue
  }
  
  init(format: String, _ arguments: CVarArg...)
  {
    self.rawValue = String(format: format, arguments: arguments)
  }
  
  init(error: NSError)
  {
    rawValue = error.localizedDescription
  }
  
  /// The string with a colon appended.
  var colon: UIString
  {
    UIString(rawValue: rawValue.appending(":"))
  }
  
  static let empty = ›""
  
  static let openPrompt = ›"Open a directory that contains a Git repository"
  static let notARepository = ›"That folder does not contain a Git repository."
  
  static let branchNameInvalid = ›"Not a valid name"
  static let branchNameExists = ›"Branch already exists"
  static let trackingBranchMissing = ›"This branch's remote tracking branch does not exist."
  static let trackingToolTip = ›"The active branch is tracking this remote branch"
  
  // Command titles (menu, button, etc)
  static let add = ›"Add"
  static let amend = ›"Amend"
  static let apply = ›"Apply"
  static let cancel = ›"Cancel"
  static let checkOut = ›"Check Out"
  static let clear = ›"Clear"
  static let clone = ›"Clone"
  static let commit = ›"Commit"
  static let copyURL = ›"Copy URL"
  static let create = ›"Create"
  static let createTrackingBranch = ›"Create Tracking Branch..."
  static let createRemote = ›"Create Remote"
  static let delete = ›"Delete"
  static let deleteBranch = ›"Delete Branch"
  static let detached = ›"Detached"
  static let dontReplace = ›"Don't Replace"
  static let discard = ›"Discard"
  static let drop = ›"Drop"
  static let edit = ›"Edit"
  static let fetch = ›"Fetch"
  static let fetchAllRemotes = ›"Fetch All Remotes"
  static let hideSidebar = ›"Hide Sidebar"
  static let merge = ›"Merge"
  static let ok = ›"OK"
  static let openPrefs = ›"Open Preferences"
  static let pop = ›"Pop"
  static let pull = ›"Pull"
  static let push = ›"Push"
  static let pushToRemote = ›"Push to Remote..."
  static let refresh = ›"Refresh"
  static let rename = ›"Rename"
  static let replace = ›"Replace"
  static let retry = ›"Retry"
  static let revert = ›"Revert"
  static let save = ›"Save"
  static let saveStash = ›"Save Stash..."
  static let showInFinder = ›"Show in Finder"
  static let showSidebar = ›"Show Sidebar"
  static let stage = ›"Stage"
  static let stageAll = ›"Stage All"
  static let staging = ›"Staging"
  static let unstage = ›"Unstage"
  static let unstageAll = ›"Unstage All"
  static let update = ›"Update"

  // Titles
  static let sidebar = ›"Sidebar"
  static let history = ›"History"
  static let files = ›"Files"

  // Sidebar roots
  static let workspace = ›"Workspace"
  static let branches = ›"Branches"
  static let remotes = ›"Remotes"
  static let tags = ›"Tags"
  static let stashes = ›"Stashes"
  static let submodules = ›"Submodules"

  // File preview strings
  static let binaryFile = ›"Not a text file"
  static let blameNotAvailable = ›"Blame not available"
  static let cantApplyHunk = ›"This hunk cannot be applied"
  static let confirmDiscardHunk = ›"Are you sure you want to discard this hunk?"
  static let multipleItemsSelected = ›"Multiple items selected"
  static let multipleSelection = ›"Multiple selection"
  static let noChanges = ›"No changes for this selection"
  static let none = ›"None"
  static let noSelection = ›"No selection"
  static let noStagedChanges = ›"No staged changes for this selection"
  static let noUnstagedChanges = ›"No unstaged changes for this selection"
  static let parent = ›"Parent:"
  static let parents = ›"Parents:"
  static let replaceMessagePrompt = ›"Replace the commit message?"
  static let replaceMessageInfo = ›"""
      Do you want to replace the commit message with the message from
      the previous commit?
      """
  static let staged = ›"Staged"
  static let whitespaceChangesHidden = ›"Whitespace changes are hidden"

  static let confirmDeleteAccount = ›"Are you sure you want to delete the selected account?"
  static let confirmRevertMultiple = ›"Revert changes to the selected files?"
  
  // Format strings
  static private let authorFormat = "%@ (author)"
  static private let checkOutFormat = #"Check out "%@""#
  static private let committerFormat = "%@ (committer)"
  static private let confirmPushFormat = #"Push local branch "%1$@" to remote "%2$@"?"#
  static private let confirmPushAllFormat = "Push all branches that track %@?"
  static private let confirmRevertFormat = "Are you sure you want to revert changes to %@?"
  static private let confirmDeleteFormat = "Delete the %1$@ %2$@?"
  static private let createTrackingFormat = "Create local branch tracking %@"
  static private let mergeFormat = #"Merge "%1$@" into "%2$@""#
  static private let renamePromptFormat = #"Rename branch "%@" to:"#
  static private let trackingMissingInfoFormat = """
      The remote branch may have been merged and deleted. Do you want to \
      clear the tracking branch setting, or delete your local branch "%@"?
      """

  static let resetSoftDescription = ›"""
      Sets the current branch to point to the selected commit, but staged \
      changes are retained and workspace files are not changed.
      """
  static let resetMixedDescription = ›"""
      Sets the current branch to point to the selected commit, and all staged \
      changes are forgotten. Workspace files are not changed.
      """
  static let resetHardDescription = ›"""
      Clears all staged and workspace changes, and sets the current branch to \
      point to the selected commit.
      """
  
  static let resetStatusClean = ›"There are no staged or workspace changes."
  static let resetStatusSafe = ›"""
      There are changes, but this option will preserve them.
      """
  static let resetStatusDataLoss = ›"""
      You have uncommitted changes that will be lost with this option.
      """

  static func author(_ name: String) -> UIString
  { .init(format: UIString.authorFormat, name) }
  static func checkOut(_ branch: String) -> UIString
  { .init(format: UIString.checkOutFormat, branch) }
  static func committer(_ name: String) -> UIString
  { .init(format: UIString.committerFormat, name) }
  static func confirmPush(localBranch: String, remote: String) -> UIString
  { .init(format: UIString.confirmPushFormat, localBranch, remote) }
  static func confirmPushAll(remote: String) -> UIString
  { .init(format: UIString.confirmPushAllFormat, remote) }
  static func confirmRevert(_ name: String) -> UIString
  { .init(format: UIString.confirmRevertFormat, name) }
  static func confirmDelete(kind: String, name: String) -> UIString
  { .init(format: UIString.confirmDeleteFormat, kind, name) }
  static func createTracking(_ remoteBranch: String) -> UIString
  { .init(format: UIString.createTrackingFormat, remoteBranch) }
  static func merge(_ source: String, _ target: String) -> UIString
  { .init(format: UIString.mergeFormat, source, target) }
  static func renamePrompt(_ branch: String) -> UIString
  { .init(format: UIString.renamePromptFormat, branch) }
  static func trackingMissingInfo(_ branch: String) -> UIString
  { .init(format: UIString.trackingMissingInfoFormat, branch) }

  static let newFileDeleted = ›"The new file will be deleted."
  
  static let noStashes = ›"Repository has no stashes."
  static let checkoutFailedConflict = ›"Checkout failed because of a conflict with local changes."
  static let checkoutFailedConflictInfo = ›"Revert or stash your changes and try again."
  static let confirmPop = ›"Apply the most recent stash, and then delete it?"
  static let confirmApply = ›"Apply the most recent stash, without deleting it?"
  static let confirmStashDelete = ›"Delete the most recent stash?"
  static let confirmStashDrop = ›"Drop (delete) the selected stash?"
  
  static let keychainInvalidURL = ›"""
      The password could not be saved to the keychain because \
      the URL is not valid.
      """
  static let keychainError = ›"""
      The password could not be saved to the keychain because \
      an unexpected error occurred.
      """
  
  // Keychain errors
  static let cantSavePassword = ›"The password could not be saved."
  static let invalidName = ›"The name is not valid."
  static let invalidURL = ›"The URL is not valid."
  static let unexpectedError = ›"An unexpected error occurred."
  
  // Services
  static let prActionFailed = ›"Pull request action failed."
  
  static private let authFailedFormat = "Signing in to the %1$@ account %2$@ failed."
  static private let buildStatusFormat = "Builds for %@"
  
  static func authFailed(service: String, account: String) -> UIString
  { .init(format: UIString.authFailedFormat, service, account) }
  static func buildStatus(_ branch: String) -> UIString
  { .init(format: UIString.buildStatusFormat, branch) }

  // Clean
  static let untrackedOnly = ›"Untracked only"
  static let ignoredOnly = ›"Ignored only"
  static let all = ›"All"
  static let ignore = ›"Ignore"
  static let cleanEntireFolder = ›"Clean entire folder"
  static let listContents = ›"List contents"
  static let contains = ›"Contains"
  static let wildcard = ›"Wildcard"
  static let regex = ›"Regex"
  static let filter = ›"Filter"
  static let cleanAll = ›"Clean All"
  static let cleanSelected = ›"Clean Selected"
  static let confirmCleanAll = ›"Are you sure you want to delete all listed files?"
  static let confirmCleanSelected = ›"Are you sure you want to delete the selected file(s)?"

  static private let itemsSelectedFormat = "%d items selected"
  static private let itemsTotalFormat = "%d item(s) total"

  static func itemSelected(_ count: Int) -> UIString
  { .init(format: UIString.itemsSelectedFormat, count) }
  static func itemsTotal(_ count: Int) -> UIString
  { .init(format: itemsTotalFormat, count) }

  // Clone
  static let checkOutBranch = ›"Check Out Branch"
  static let cloneTitle = ›"Clone a Repository"
  static let cloneTo = ›"Clone to"
  static let cloning = ›"Cloning..."
  static let fullPath = ›"Full path"
  static let name = ›"Name"
  static let sourceURL = ›"Source URL"
  static let unavailable = ›"Unavailable"

  // Pull request status
  static let approved = ›"Approved"
  static let needsWork = ›"Needs work"
  static let merged = ›"Merged"
  static let closed = ›"Closed"

  // Fetch/push/pull commands
  static let fetchCurrentUnavailable = ›"Fetch Current Branch"
  static let pushCurrentUnavailable = ›"No Tracking Branch to Push"
  static let pullCurrentUnavailable = ›"No Tracking Branch to Pull"
  
  static let pushNew = ›"Push to New Remote Branch..."

  static private let fetchCurrentFormat = #"Fetch "%2$@/%1$@""#
  static private let fetchRemoteFormat = #"Fetch Remote "%@""#
  static private let pushCurrentFormat = #"Push to "%2$@/%1$@""#
  static private let pushRemoteFormat = #"Push to Any Tracking Branches on "%@""#
  static private let pullCurrentFormat = #"Pull from "%2$@/%1@""#
  static private let pullRemoteFormat = #"Pull Tracking Branches on "%@""#

  static func fetchCurrent(branch: String, remote: String) -> UIString
  { .init(format: fetchCurrentFormat, branch, remote) }
  static func fetchRemote(_ remote: String) -> UIString
  { .init(format: fetchRemoteFormat, remote) }
  static func pushCurrent(branch: String, remote: String) -> UIString
  { .init(format: pushCurrentFormat, branch, remote) }
  static func pushRemote(_ remote: String) -> UIString
  { .init(format: pushRemoteFormat, remote) }
  static func pullCurrent(branch: String, remote: String) -> UIString
  { .init(format: pullCurrentFormat, branch, remote) }
  static func pullRemote(_ remote: String) -> UIString
  { .init(format: pullRemoteFormat, remote) }

  // Repository errors
  static private let gitErrorFormat = "An internal git error (%d) occurred."
  static private let commitNotFoundFormat = "The commit %@ was not found."
  static private let fileNotFoundFormat = "The file %@ was not found."
  static private let invalidNameFormat = "The name %@ is not valid."
  static private let noRemoteBranchesFormat = #"No branches found on "%@" to push to."#

  static func gitError(_ error: Int32) -> UIString
  { .init(format: UIString.gitErrorFormat, error) }
  static func commitNotFound(_ sha: String?) -> UIString
  { .init(format: UIString.commitNotFoundFormat, sha ?? "-") }
  static func fileNotFound(_ file: String) -> UIString
  { .init(format: UIString.fileNotFoundFormat, file) }
  static func invalidName(_ name: String) -> UIString
  { .init(format: UIString.invalidNameFormat, name) }
  static func noRemoteBranches(_ remote: String) -> UIString
  { .init(format: UIString.noRemoteBranchesFormat, remote) }

  static let alreadyWriting = ›"A writing operation is already in progress."
  static let invalidNameGiven = ›"The name is invalid"
  static let mergeInProgress = ›"A merge operation is already in progress."
  static let cherryPickInProgress = ›"A cherry-pick operation is already in progress."
  static let conflict = ›"""
      The operation could not be completed because there were conflicts.
      """
  static let localConflict = ›"""
      There are conflicted files in the work tree or index.
      Try checking in or stashing your changes first.
      """
  static let detachedHead = ›"This operation cannot be performed in a detached HEAD state."
  static let duplicateName = ›"That name is already in use."
  static let patchMismatch = ›"""
      The patch could not be applied because it did not match the
      file content.
      """
  static let notFound = ›"The item was not found."
  static let unexpected = ›"An unexpected repository error occurred."
  static let workspaceDirty = ›"There are uncommitted changes."
  static let pushToBare = ›"Pushing to a bare local repository is currently not supported."
}

extension UIString: Comparable
{
  static func < (lhs: UIString, rhs: UIString) -> Bool
  {
    return lhs.rawValue < rhs.rawValue
  }
}
