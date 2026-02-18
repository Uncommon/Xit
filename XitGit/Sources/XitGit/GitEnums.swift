import Foundation
import Clibgit2

// MARK: - Enums from GitEnums.h translated to Swift

public enum DeltaStatus: UInt32, CaseIterable, Sendable
{
    case unmodified = 0 // GIT_DELTA_UNMODIFIED
    case added = 1      // GIT_DELTA_ADDED
    case deleted = 2    // GIT_DELTA_DELETED
    case modified = 3   // GIT_DELTA_MODIFIED
    case renamed = 4    // GIT_DELTA_RENAMED
    case copied = 5     // GIT_DELTA_COPIED
    case ignored = 6    // GIT_DELTA_IGNORED
    case untracked = 7  // GIT_DELTA_UNTRACKED
    case typeChange = 8 // GIT_DELTA_TYPECHANGE
    case unreadable = 9 // GIT_DELTA_UNREADABLE
    case conflict = 10  // GIT_DELTA_CONFLICTED
    
    // Custom value not in libgit2, used for UI/Logic
    case mixed = 999 
    
    public init(gitDelta: git_delta_t)
    {
        self = DeltaStatus(rawValue: gitDelta.rawValue) ?? .unmodified
    }
}

public struct DiffFlags: OptionSet, Sendable
{
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    
    public static let binary = DiffFlags(rawValue: GIT_DIFF_FLAG_BINARY.rawValue)
    public static let notBinary = DiffFlags(rawValue: GIT_DIFF_FLAG_NOT_BINARY.rawValue)
    public static let validOID = DiffFlags(rawValue: GIT_DIFF_FLAG_VALID_ID.rawValue)
    public static let exists = DiffFlags(rawValue: GIT_DIFF_FLAG_EXISTS.rawValue)
}

public enum DiffLineType: UInt32, Sendable
{
    case context = 32         // GIT_DIFF_LINE_CONTEXT = ' '
    case addition = 43        // GIT_DIFF_LINE_ADDITION = '+'
    case deletion = 45        // GIT_DIFF_LINE_DELETION = '-'
    case contextEOFNL = 61    // GIT_DIFF_LINE_CONTEXT_EOFNL = '='
    case addEOFNL = 62        // GIT_DIFF_LINE_ADD_EOFNL = '>'
    case deleteEOFNL = 60     // GIT_DIFF_LINE_DEL_EOFNL = '<'
    case fileHeader = 70      // GIT_DIFF_LINE_FILE_HDR = 'F'
    case hunkHeader = 72      // GIT_DIFF_LINE_HUNK_HDR = 'H'
    case binary = 66          // GIT_DIFF_LINE_BINARY = 'B'
}

public struct DiffOptionFlags: OptionSet, Sendable
{
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    
    public static let normal = DiffOptionFlags(rawValue: GIT_DIFF_NORMAL.rawValue)
    public static let reverse = DiffOptionFlags(rawValue: GIT_DIFF_REVERSE.rawValue)
    public static let includeIgnored = DiffOptionFlags(rawValue: GIT_DIFF_INCLUDE_IGNORED.rawValue)
    public static let recurseIgnoredDirs = DiffOptionFlags(rawValue: GIT_DIFF_RECURSE_IGNORED_DIRS.rawValue)
    public static let includeUntracked = DiffOptionFlags(rawValue: GIT_DIFF_INCLUDE_UNTRACKED.rawValue)
    public static let recurseUntrackedDirs = DiffOptionFlags(rawValue: GIT_DIFF_RECURSE_UNTRACKED_DIRS.rawValue)
    public static let includeUnmodified = DiffOptionFlags(rawValue: GIT_DIFF_INCLUDE_UNMODIFIED.rawValue)
    public static let includeTypeChange = DiffOptionFlags(rawValue: GIT_DIFF_INCLUDE_TYPECHANGE.rawValue)
    public static let includeTypeChangeTrees = DiffOptionFlags(rawValue: GIT_DIFF_INCLUDE_TYPECHANGE_TREES.rawValue)
    public static let ignoreFileMode = DiffOptionFlags(rawValue: GIT_DIFF_IGNORE_FILEMODE.rawValue)
    public static let ignoreSubmodules = DiffOptionFlags(rawValue: GIT_DIFF_IGNORE_SUBMODULES.rawValue)
    public static let ignoreCase = DiffOptionFlags(rawValue: GIT_DIFF_IGNORE_CASE.rawValue)
    public static let includeCaseChange = DiffOptionFlags(rawValue: GIT_DIFF_INCLUDE_CASECHANGE.rawValue)
    public static let disablePathspecMatch = DiffOptionFlags(rawValue: GIT_DIFF_DISABLE_PATHSPEC_MATCH.rawValue)
    public static let skipBinaryCheck = DiffOptionFlags(rawValue: GIT_DIFF_SKIP_BINARY_CHECK.rawValue)
    public static let enableFastUntrackedDirs = DiffOptionFlags(rawValue: GIT_DIFF_ENABLE_FAST_UNTRACKED_DIRS.rawValue)
    public static let updateIndex = DiffOptionFlags(rawValue: GIT_DIFF_UPDATE_INDEX.rawValue)
    
    public static let forceText = DiffOptionFlags(rawValue: GIT_DIFF_FORCE_TEXT.rawValue)
    public static let forceBinary = DiffOptionFlags(rawValue: GIT_DIFF_FORCE_BINARY.rawValue)
    public static let ignoreWhitespace = DiffOptionFlags(rawValue: GIT_DIFF_IGNORE_WHITESPACE.rawValue)
    public static let ignoreWhitespaceChange = DiffOptionFlags(rawValue: GIT_DIFF_IGNORE_WHITESPACE_CHANGE.rawValue)
    public static let ignoreWhitespaceEOL = DiffOptionFlags(rawValue: GIT_DIFF_IGNORE_WHITESPACE_EOL.rawValue)
    public static let showUntrackedContent = DiffOptionFlags(rawValue: GIT_DIFF_SHOW_UNTRACKED_CONTENT.rawValue)
    public static let showUnmodified = DiffOptionFlags(rawValue: GIT_DIFF_SHOW_UNMODIFIED.rawValue)
    public static let patience = DiffOptionFlags(rawValue: GIT_DIFF_PATIENCE.rawValue)
    public static let minimal = DiffOptionFlags(rawValue: GIT_DIFF_MINIMAL.rawValue)
    public static let showBinary = DiffOptionFlags(rawValue: GIT_DIFF_SHOW_BINARY.rawValue)
}

public struct DiffStatsFormat: OptionSet, Sendable
{
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    
    public static let none = DiffStatsFormat(rawValue: GIT_DIFF_STATS_NONE.rawValue)
    public static let full = DiffStatsFormat(rawValue: GIT_DIFF_STATS_FULL.rawValue)
    public static let short = DiffStatsFormat(rawValue: GIT_DIFF_STATS_SHORT.rawValue)
    public static let number = DiffStatsFormat(rawValue: GIT_DIFF_STATS_NUMBER.rawValue)
    public static let includeSummary = DiffStatsFormat(rawValue: GIT_DIFF_STATS_INCLUDE_SUMMARY.rawValue)
}

public enum ReferenceType: Int32, Sendable
{
    case invalid = 0 // GIT_REFERENCE_INVALID
    case direct = 1  // GIT_REFERENCE_DIRECT
    case symbolic = 2 // GIT_REFERENCE_SYMBOLIC
    case listAll = 3  // GIT_REFERENCE_ALL
}

public enum GitObjectType: Int32, Sendable
{
    case any = -2      // GIT_OBJECT_ANY
    case invalid = -1  // GIT_OBJECT_INVALID
    case commit = 1    // GIT_OBJECT_COMMIT
    case tree = 2      // GIT_OBJECT_TREE
    case blob = 3      // GIT_OBJECT_BLOB
    case tag = 4       // GIT_OBJECT_TAG
    case offsetDelta = 6 // GIT_OBJECT_OFS_DELTA
    case refDelta = 7    // GIT_OBJECT_REF_DELTA
}

public enum StatusShow: Int32, Sendable
{
    case indexAndWorkdir = 0 // GIT_STATUS_SHOW_INDEX_AND_WORKDIR
    case indexOnly = 1       // GIT_STATUS_SHOW_INDEX_ONLY
    case workdirOnly = 2     // GIT_STATUS_SHOW_WORKDIR_ONLY
}

public struct StatusFlags: OptionSet, Sendable
{
    public let rawValue: UInt32
    // git_status_t in simple imports comes as UInt32 usually?
    // Let's check. Assuming UInt32 for OptionSet.
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    
    public static let indexNew = StatusFlags(rawValue: GIT_STATUS_INDEX_NEW.rawValue)
    public static let indexModified = StatusFlags(rawValue: GIT_STATUS_INDEX_MODIFIED.rawValue)
    public static let indexDeleted = StatusFlags(rawValue: GIT_STATUS_INDEX_DELETED.rawValue)
    public static let indexRenamed = StatusFlags(rawValue: GIT_STATUS_INDEX_RENAMED.rawValue)
    public static let indexTypeChange = StatusFlags(rawValue: GIT_STATUS_INDEX_TYPECHANGE.rawValue)
    
    public static let worktreeNew = StatusFlags(rawValue: GIT_STATUS_WT_NEW.rawValue)
    public static let worktreeModified = StatusFlags(rawValue: GIT_STATUS_WT_MODIFIED.rawValue)
    public static let worktreeDeleted = StatusFlags(rawValue: GIT_STATUS_WT_DELETED.rawValue)
    public static let worktreeRenamed = StatusFlags(rawValue: GIT_STATUS_WT_RENAMED.rawValue)
    public static let worktreeTypeChange = StatusFlags(rawValue: GIT_STATUS_WT_TYPECHANGE.rawValue)
    public static let worktreeUnreadable = StatusFlags(rawValue: GIT_STATUS_WT_UNREADABLE.rawValue)
    
    public static let ignored = StatusFlags(rawValue: GIT_STATUS_IGNORED.rawValue)
    public static let conflicted = StatusFlags(rawValue: GIT_STATUS_CONFLICTED.rawValue)
}

public struct StatusOptions: OptionSet, Sendable
{
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    
    public static let includeUntracked = StatusOptions(rawValue: GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue)
    public static let includeIgnored = StatusOptions(rawValue: GIT_STATUS_OPT_INCLUDE_IGNORED.rawValue)
    public static let includeUnmodified = StatusOptions(rawValue: GIT_STATUS_OPT_INCLUDE_UNMODIFIED.rawValue)
    public static let excludeSubmodules = StatusOptions(rawValue: GIT_STATUS_OPT_EXCLUDE_SUBMODULES.rawValue)
    public static let recurseUntrackedDirs = StatusOptions(rawValue: GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue)
    public static let disablePathspecMatch = StatusOptions(rawValue: GIT_STATUS_OPT_DISABLE_PATHSPEC_MATCH.rawValue)
    public static let recurseIgnoredDirs = StatusOptions(rawValue: GIT_STATUS_OPT_RECURSE_IGNORED_DIRS.rawValue)
    public static let renamesHeadToIndex = StatusOptions(rawValue: GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX.rawValue)
    public static let renamesIndexToWorkdir = StatusOptions(rawValue: GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR.rawValue)
    public static let sortCaseSensitively = StatusOptions(rawValue: GIT_STATUS_OPT_SORT_CASE_SENSITIVELY.rawValue)
    public static let sortCaseInsensitively = StatusOptions(rawValue: GIT_STATUS_OPT_SORT_CASE_INSENSITIVELY.rawValue)
    public static let renamesFromRewrites = StatusOptions(rawValue: GIT_STATUS_OPT_RENAMES_FROM_REWRITES.rawValue)
    public static let noRefresh = StatusOptions(rawValue: GIT_STATUS_OPT_NO_REFRESH.rawValue)
    public static let updateIndex = StatusOptions(rawValue: GIT_STATUS_OPT_UPDATE_INDEX.rawValue)
    public static let includeUnreadable = StatusOptions(rawValue: GIT_STATUS_OPT_INCLUDE_UNREADABLE.rawValue)
    public static let includeUnreadableAsUntracked = StatusOptions(rawValue: GIT_STATUS_OPT_INCLUDE_UNREADABLE_AS_UNTRACKED.rawValue)
    
    public static let amending = StatusOptions(rawValue: 1 << 20)
}

public struct CheckoutStrategy: OptionSet, Sendable
{
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    
    public static let safe = CheckoutStrategy(rawValue: GIT_CHECKOUT_SAFE.rawValue)
    public static let force = CheckoutStrategy(rawValue: GIT_CHECKOUT_FORCE.rawValue)
    public static let recreateMissing = CheckoutStrategy(rawValue: GIT_CHECKOUT_RECREATE_MISSING.rawValue)
    public static let allowConflicts = CheckoutStrategy(rawValue: GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue)
    public static let removeUntracked = CheckoutStrategy(rawValue: GIT_CHECKOUT_REMOVE_UNTRACKED.rawValue)
    public static let removeIgnored = CheckoutStrategy(rawValue: GIT_CHECKOUT_REMOVE_IGNORED.rawValue)
    public static let updateOnly = CheckoutStrategy(rawValue: GIT_CHECKOUT_UPDATE_ONLY.rawValue)
    public static let dontUpdateIndex = CheckoutStrategy(rawValue: GIT_CHECKOUT_DONT_UPDATE_INDEX.rawValue)
    public static let noRefresh = CheckoutStrategy(rawValue: GIT_CHECKOUT_NO_REFRESH.rawValue)
    public static let skipUnmerged = CheckoutStrategy(rawValue: GIT_CHECKOUT_SKIP_UNMERGED.rawValue)
    public static let useOurs = CheckoutStrategy(rawValue: GIT_CHECKOUT_USE_OURS.rawValue)
    public static let useTheirs = CheckoutStrategy(rawValue: GIT_CHECKOUT_USE_THEIRS.rawValue)
    public static let disablePathspecMatch = CheckoutStrategy(rawValue: GIT_CHECKOUT_DISABLE_PATHSPEC_MATCH.rawValue)
    public static let skipLockedDirectories = CheckoutStrategy(rawValue: GIT_CHECKOUT_SKIP_LOCKED_DIRECTORIES.rawValue)
    public static let dontOverwriteIgnored = CheckoutStrategy(rawValue: GIT_CHECKOUT_DONT_OVERWRITE_IGNORED.rawValue)
    public static let conflictStyleMerge = CheckoutStrategy(rawValue: GIT_CHECKOUT_CONFLICT_STYLE_MERGE.rawValue)
    public static let conflictStyleDiff3 = CheckoutStrategy(rawValue: GIT_CHECKOUT_CONFLICT_STYLE_DIFF3.rawValue)
    public static let dontRemoveExisting = CheckoutStrategy(rawValue: GIT_CHECKOUT_DONT_REMOVE_EXISTING.rawValue)
    public static let dontWriteIndex = CheckoutStrategy(rawValue: GIT_CHECKOUT_DONT_WRITE_INDEX.rawValue)
    public static let updateSubmodules = CheckoutStrategy(rawValue: GIT_CHECKOUT_UPDATE_SUBMODULES.rawValue)
    public static let updateSubmodulesIfChanged = CheckoutStrategy(rawValue: GIT_CHECKOUT_UPDATE_SUBMODULES_IF_CHANGED.rawValue)
}

// MARK: - Extensions from GitEnums.swift

extension DeltaStatus
{  
  public init(indexStatus: git_status_t)
  {
      // Convert flags to status
    switch indexStatus {
      case GIT_STATUS_CURRENT:
        self = .unmodified
      case let status where (status.rawValue & GIT_STATUS_INDEX_MODIFIED.rawValue) != 0:
        self = .modified
      case let status where (status.rawValue & GIT_STATUS_INDEX_NEW.rawValue) != 0:
        self = .added
      case let status where (status.rawValue & GIT_STATUS_INDEX_DELETED.rawValue) != 0:
        self = .deleted
      case let status where (status.rawValue & GIT_STATUS_INDEX_RENAMED.rawValue) != 0:
        self = .renamed
      case let status where (status.rawValue & GIT_STATUS_INDEX_TYPECHANGE.rawValue) != 0:
        self = .typeChange
      case let status where (status.rawValue & GIT_STATUS_IGNORED.rawValue) != 0:
        self = .ignored
      case let status where (status.rawValue & GIT_STATUS_CONFLICTED.rawValue) != 0:
        self = .conflict
      default:
        self = .unmodified
    }
  }
  
  public init(worktreeStatus: git_status_t)
  {
    switch worktreeStatus {
      case GIT_STATUS_CURRENT:
        self = .unmodified
      case let status where (status.rawValue & GIT_STATUS_WT_MODIFIED.rawValue) != 0:
        self = .modified
      case let status where (status.rawValue & GIT_STATUS_WT_NEW.rawValue) != 0:
        self = .added
      case let status where (status.rawValue & GIT_STATUS_WT_DELETED.rawValue) != 0:
        self = .deleted
      case let status where (status.rawValue & GIT_STATUS_WT_RENAMED.rawValue) != 0:
        self = .renamed
      case let status where (status.rawValue & GIT_STATUS_WT_TYPECHANGE.rawValue) != 0:
        self = .typeChange
      case GIT_STATUS_CONFLICTED:
        self = .conflict
      default:
        self = .unmodified
    }
  }
  
  public var isModified: Bool
  {
    switch self {
      case .unmodified, .untracked:
        return false
      default:
        return true
    }
  }
}

extension git_status_t
{
  func contains(_ other: git_status_t) -> Bool
  {
    (rawValue & other.rawValue) != 0
  }
}

extension git_credential_t
{
  func contains(_ other: git_credential_t) -> Bool
  {
    (rawValue & other.rawValue) != 0
  }
}

extension DeltaStatus: CustomStringConvertible
{
  public var description: String
  {
    switch self {
      case .unmodified: return "unmodified"
      case .added: return "added"
      case .deleted: return "deleted"
      case .modified: return "modified"
      case .renamed: return "renamed"
      case .copied: return "copied"
      case .ignored: return "ignored"
      case .untracked: return "untracked"
      case .typeChange: return "type change"
      case .conflict: return "conflict"
      case .mixed: return "mixed"
      case .unreadable: return "unreadable"
    }
  }
}

extension DeltaStatus: Comparable
{
  private var order: Int
  {
    switch self {
      case .conflict:
        return 0
      case .added:
        return 1
      case .deleted:
        return 2
      case .modified:
        return 3
      case .renamed:
        return 4
      case .copied:
        return 5
      case .typeChange:
        return 6
      case .mixed:
        return 7
      case .ignored:
        return 8
      case .untracked:
        return 9
      case .unmodified:
        return 10
      case .unreadable:
        return 11
    }
  }

  public static func < (lhs: DeltaStatus, rhs: DeltaStatus) -> Bool
  {
    return lhs.order < rhs.order
  }
}
