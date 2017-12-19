#import <ObjectiveGit/ObjectiveGit.h>

// Swift requires that raw values be literals, so this needs to be a C enum.
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

typedef NS_ENUM(int, GitObjectType) {
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
