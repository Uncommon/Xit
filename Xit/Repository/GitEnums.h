#import <ObjectiveGit/ObjectiveGit.h>

// Swift requires that raw values be literals, but the values need to match
// the values from libgit2, so using C enums is a workaround.

typedef NS_ENUM(unsigned int, DeltaStatus)
{
  DeltaStatusUnmodified = GIT_DELTA_UNMODIFIED,
  DeltaStatusAdded = GIT_DELTA_ADDED,
  DeltaStatusDeleted = GIT_DELTA_DELETED,
  DeltaStatusModified = GIT_DELTA_MODIFIED,
  DeltaStatusRenamed = GIT_DELTA_RENAMED,
  DeltaStatusCopied = GIT_DELTA_COPIED,
  DeltaStatusIgnored = GIT_DELTA_IGNORED,
  DeltaStatusUntracked = GIT_DELTA_UNTRACKED,
  DeltaStatusTypeChange = GIT_DELTA_TYPECHANGE,
  DeltaStatusConflict = GIT_DELTA_CONFLICTED,
  DeltaStatusMixed,  // For folders containing a mix of changes
};

typedef NS_OPTIONS(unsigned int, DiffFlags)
{
  DiffFlagsBinary = GIT_DIFF_FLAG_BINARY,
  DiffFlagsNotBinary = GIT_DIFF_FLAG_NOT_BINARY,
  DiffFlagsValidOID = GIT_DIFF_FLAG_VALID_ID,
  DiffFlagsExists = GIT_DIFF_FLAG_EXISTS,
};

typedef NS_ENUM(unsigned int, DiffLineType)
{
  DiffLineTypeContext = GIT_DIFF_LINE_CONTEXT,
  DiffLineTypeAddition = GIT_DIFF_LINE_ADDITION,
  DiffLineTypeDeletion = GIT_DIFF_LINE_DELETION,
  DiffLineTypeContextEOFNL = GIT_DIFF_LINE_CONTEXT_EOFNL,
  DiffLineTypeAddEOFNL = GIT_DIFF_LINE_ADD_EOFNL,
  DiffLineTypeDeleteEOFNL = GIT_DIFF_LINE_DEL_EOFNL,
};

typedef NS_OPTIONS(unsigned int, DiffOptionFlags)
{
  DiffOptionFlagsReverse = GIT_DIFF_REVERSE,
  DiffOptionFlagsIncludeIgnored = GIT_DIFF_INCLUDE_IGNORED,
  DiffOptionFlagsRecurseIgnoredDirectories = GIT_DIFF_RECURSE_IGNORED_DIRS,
  DiffOptionFlagsIncludeUntracked = GIT_DIFF_INCLUDE_UNTRACKED,
  DiffOptionFlagsRecurseUntracked = GIT_DIFF_RECURSE_UNTRACKED_DIRS,
  DiffOptionFlagsIncludeUnmodified = GIT_DIFF_INCLUDE_UNMODIFIED,
  DiffOptionFlagsIncludeTypeChange = GIT_DIFF_INCLUDE_TYPECHANGE,
  DiffOptionFlagsIncludeTypeChangeTrees = GIT_DIFF_INCLUDE_TYPECHANGE_TREES,
  DiffOptionFlagsIgnoreFileMode = GIT_DIFF_IGNORE_FILEMODE,
  DiffOptionFlagsIgnoreSubmodules = GIT_DIFF_IGNORE_SUBMODULES,
  DiffOptionFlagsIgnoreCase = GIT_DIFF_IGNORE_CASE,
  DiffOptionFlagsIncludeCaseChange = GIT_DIFF_INCLUDE_CASECHANGE,
  DiffOptionFlagsDisablePathspecMatch = GIT_DIFF_DISABLE_PATHSPEC_MATCH,
  DiffOptionFlagsSkipBinaryCheck = GIT_DIFF_SKIP_BINARY_CHECK,
  DiffOptionFlagsEnableFastUntrackedDirectories = GIT_DIFF_ENABLE_FAST_UNTRACKED_DIRS,
  DiffOptionFlagsUpdateIndex = GIT_DIFF_UPDATE_INDEX,
  DiffOptionFlagsIncludeUnreadable = GIT_DIFF_INCLUDE_UNREADABLE,
  DiffOptionFlagsIncludeUnreadableAsUntracked = GIT_DIFF_INCLUDE_UNREADABLE_AS_UNTRACKED,
  
  DiffOptionFlagsForceText = GIT_DIFF_FORCE_TEXT,
  DiffOptionFlagsForceBinary = GIT_DIFF_FORCE_BINARY,
  DiffOptionFlagsIgnoreWhitespace = GIT_DIFF_IGNORE_WHITESPACE,
  DiffOptionFlagsIgnoreWhitespaceChange = GIT_DIFF_IGNORE_WHITESPACE_CHANGE,
  DiffOptionFlagsIgnoreWhitespaceEOL = GIT_DIFF_IGNORE_WHITESPACE_EOL,
  DiffOptionFlagsShowUntrackedContent = GIT_DIFF_SHOW_UNTRACKED_CONTENT,
  DiffOptionFlagsShowUnmodified = GIT_DIFF_SHOW_UNMODIFIED,
  DiffOptionFlagsPatience = GIT_DIFF_PATIENCE,
  DiffOptionFlagsMinimal = GIT_DIFF_MINIMAL,
  DiffOptionFlagsShowBinary = GIT_DIFF_SHOW_BINARY,
};

typedef NS_ENUM(int, ReferenceType)
{
  ReferenceTypeInvalid = GIT_REF_INVALID,
  ReferenceTypeOID = GIT_REF_OID,
  ReferenceTypeSymbolic = GIT_REF_SYMBOLIC,
  ReferenceTypeListAll = GIT_REF_LISTALL,
};

typedef NS_ENUM(int, GitObjectType)
{
  GitObjectTypeAny = GIT_OBJ_ANY,
  GitObjectTypeBad = GIT_OBJ_BAD,
  GitObjectTypeExt1 = GIT_OBJ__EXT1,
  GitObjectTypeCommit = GIT_OBJ_COMMIT,
  GitObjectTypeTree = GIT_OBJ_TREE,
  GitObjectTypeBlob = GIT_OBJ_BLOB,
  GitObjectTypeTag = GIT_OBJ_TAG,
  GitObjectTypeExt2 = GIT_OBJ__EXT2,
  GitObjectTypeOffsetDelta = GIT_OBJ_OFS_DELTA,
  GitObjectTypeRefDelta = GIT_OBJ_REF_DELTA,
};

typedef NS_ENUM(int, StatusShow)
{
  StatusShowIndexAndWorkdir = GIT_STATUS_SHOW_INDEX_AND_WORKDIR,
  StatusShowIndexOnly = GIT_STATUS_SHOW_INDEX_ONLY,
  StatusShowWorkdirOnly = GIT_STATUS_SHOW_WORKDIR_ONLY,
};

typedef NS_OPTIONS(int, StatusFlags)
{
  //GIT_STATUS_CURRENT,
  
  StatusFlagsIndexNew        = GIT_STATUS_INDEX_NEW,
  StatusFlagsIndexModified   = GIT_STATUS_INDEX_MODIFIED,
  StatusFlagsIndexDeleted    = GIT_STATUS_INDEX_DELETED,
  StatusFlagsIndexRenamed    = GIT_STATUS_INDEX_RENAMED,
  StatusFlagsIndexTypeChange = GIT_STATUS_INDEX_TYPECHANGE,
  
  StatusFlagsWorktreeNew        = GIT_STATUS_WT_NEW,
  StatusFlagsWorktreeModified   = GIT_STATUS_WT_MODIFIED,
  StatusFlagsWorktreeDeleted    = GIT_STATUS_WT_DELETED,
  StatusFlagsWorktreeRenamed    = GIT_STATUS_WT_RENAMED,
  StatusFlagsWorktreeTypeChange = GIT_STATUS_WT_TYPECHANGE,
  StatusFlagsWorktreeUnreadable = GIT_STATUS_WT_UNREADABLE,
  
  StatusFlagsIgnored = GIT_STATUS_IGNORED,
  StatusFlagsConflicted = GIT_STATUS_CONFLICTED,
};

typedef NS_OPTIONS(int, StatusOptions)
{
  StatusOptionsIncludeUntracked = GIT_STATUS_OPT_INCLUDE_UNTRACKED,
  StatusOptionsIncludeIgnored = GIT_STATUS_OPT_INCLUDE_IGNORED,
  StatusOptionsIncludeUnmodified = GIT_STATUS_OPT_INCLUDE_UNMODIFIED,
  StatusOptionsExcludeSubmodules = GIT_STATUS_OPT_EXCLUDE_SUBMODULES,
  StatusOptionsRecurseUntrackedDirs = GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS,
  StatusOptionsDisablePathspecMatch = GIT_STATUS_OPT_DISABLE_PATHSPEC_MATCH,
  StatusOptionsRecurseIgnoredDirs = GIT_STATUS_OPT_RECURSE_IGNORED_DIRS,
  StatusOptionsRenamesHeadToIndex = GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX,
  StatusOptionsRenamesIndexToWorkdir = GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR,
  StatusOptionsSortCaseSensitively = GIT_STATUS_OPT_SORT_CASE_SENSITIVELY,
  StatusOptionsSortCaseInsensitively = GIT_STATUS_OPT_SORT_CASE_INSENSITIVELY,
  StatusOptionsRenamesFromRewrites = GIT_STATUS_OPT_RENAMES_FROM_REWRITES,
  StatusOptionsNoRefresh = GIT_STATUS_OPT_NO_REFRESH,
  StatusOptionsUpdateIndex = GIT_STATUS_OPT_UPDATE_INDEX,
  StatusOptionsIncludeUnreadable = GIT_STATUS_OPT_INCLUDE_UNREADABLE,
  StatusOptionsIncludeUnreadableAsUntracked = GIT_STATUS_OPT_INCLUDE_UNREADABLE_AS_UNTRACKED,
  // Custom flag. git_status_opt_t goes up to << 15.
  StatusOptionsAmending = 1u << 20
};

typedef NS_OPTIONS(int, CheckoutStrategy)
{
  CheckoutStrategySafe = GIT_CHECKOUT_SAFE,
  CheckoutStrategyForce = GIT_CHECKOUT_FORCE,
  CheckoutStrategyRecreateMissing = GIT_CHECKOUT_RECREATE_MISSING,
  CheckoutStrategyAllowConflicts = GIT_CHECKOUT_ALLOW_CONFLICTS,
  CheckoutStrategyRemoveUntracked = GIT_CHECKOUT_REMOVE_UNTRACKED,
  CheckoutStrategyRemoveIgnored = GIT_CHECKOUT_REMOVE_IGNORED,
  CheckoutStrategyUpdateOnly = GIT_CHECKOUT_UPDATE_ONLY,
  CheckoutStrategyDontUpdateIndex = GIT_CHECKOUT_DONT_UPDATE_INDEX,
  CheckoutStrategyNoRefresh = GIT_CHECKOUT_NO_REFRESH,
  CheckoutStrategySkipUnmerged = GIT_CHECKOUT_SKIP_UNMERGED,
  CheckoutStrategyUseOurs = GIT_CHECKOUT_USE_OURS,
  CheckoutStrategyUseTheirs = GIT_CHECKOUT_USE_THEIRS,
  CheckoutStrategyDisablePathspecMatch = GIT_CHECKOUT_DISABLE_PATHSPEC_MATCH,
  CheckoutStrategySkipLockedDirectories = GIT_CHECKOUT_SKIP_LOCKED_DIRECTORIES,
  CheckoutStrategyDontOverwriteIgnored = GIT_CHECKOUT_DONT_OVERWRITE_IGNORED,
  CheckoutStrategyConflictStyleMerge = GIT_CHECKOUT_CONFLICT_STYLE_MERGE,
  CheckoutStrategyConflictStyleDiff3 = GIT_CHECKOUT_CONFLICT_STYLE_DIFF3,
  CheckoutStrategyDontRemoveExisting = GIT_CHECKOUT_DONT_REMOVE_EXISTING,
  CheckoutStrategyDontWriteIndex = GIT_CHECKOUT_DONT_WRITE_INDEX,
  CheckoutStrategyUpdateSubmodules = GIT_CHECKOUT_UPDATE_SUBMODULES,
  CheckoutStrategyUpdateSubmodulesIfChanged = GIT_CHECKOUT_UPDATE_SUBMODULES_IF_CHANGED,
};

typedef NS_ENUM(int, SubmoduleIgnore)
{
  SubmoduleIgnoreNone = GIT_SUBMODULE_IGNORE_NONE,
  SubmoduleIgnoreUntracked = GIT_SUBMODULE_IGNORE_UNTRACKED,
  SubmoduleIgnoreDirty = GIT_SUBMODULE_IGNORE_DIRTY,
  SubmoduleIgnoreAll = GIT_SUBMODULE_IGNORE_ALL,
  SubmoduleIgnoreUnspecified = GIT_SUBMODULE_IGNORE_UNSPECIFIED,
};

typedef NS_ENUM(unsigned int, SubmoduleRecurse)
{
  SubmoduleRecurseNo = GIT_SUBMODULE_RECURSE_NO,
  SubmoduleRecurseYes = GIT_SUBMODULE_RECURSE_YES,
  SubmoduleRecurseOnDemand = GIT_SUBMODULE_RECURSE_ONDEMAND,
};

typedef NS_ENUM(unsigned int, SubmoduleUpdate)
{
  SubmoduleUpdateCheckout = GIT_SUBMODULE_UPDATE_CHECKOUT,
  SubmoduleUpdateRebase = GIT_SUBMODULE_UPDATE_REBASE,
  SubmoduleUpdateMerge = GIT_SUBMODULE_UPDATE_MERGE,
  SubmoduleUpdateNone = GIT_SUBMODULE_UPDATE_NONE,
  SubmoduleUpdateDefault = GIT_SUBMODULE_UPDATE_DEFAULT,
};

typedef NS_OPTIONS(int, SubmoduleStatus)
{
  SubmoduleStatusInHead = GIT_SUBMODULE_STATUS_IN_HEAD,
  SubmoduleStatusInIndex = GIT_SUBMODULE_STATUS_IN_INDEX,
  SubmoduleStatusInConfig = GIT_SUBMODULE_STATUS_IN_CONFIG,
  SubmoduleStatusInWorkDir = GIT_SUBMODULE_STATUS_IN_WD,
  SubmoduleStatusIndexAdded = GIT_SUBMODULE_STATUS_INDEX_ADDED,
  SubmoduleStatusIndexDeleted = GIT_SUBMODULE_STATUS_INDEX_DELETED,
  SubmoduleStatusIndexModified = GIT_SUBMODULE_STATUS_INDEX_MODIFIED,
  SubmoduleStatusWorkDirUninitialized = GIT_SUBMODULE_STATUS_WD_UNINITIALIZED,
  SubmoduleStatusWorkDirAdded = GIT_SUBMODULE_STATUS_WD_ADDED,
  SubmoduleStatusWorkDirDeleted = GIT_SUBMODULE_STATUS_WD_DELETED,
  SubmoduleStatusWorkDirModified = GIT_SUBMODULE_STATUS_WD_MODIFIED,
  SubmoduleStatusWorkDirIndexModified = GIT_SUBMODULE_STATUS_WD_INDEX_MODIFIED,
  SubmoduleStatusWorkDirWdModified = GIT_SUBMODULE_STATUS_WD_WD_MODIFIED,
  SubmoduleStatusWorkDirUntracked = GIT_SUBMODULE_STATUS_WD_UNTRACKED,
};
