#import <ObjectiveGit/ObjectiveGit.h>

// Swift requires that raw values be literals, so this needs to be a C enum.
typedef NS_ENUM(NSUInteger, DeltaStatus) {
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
