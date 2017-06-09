#import <ObjectiveGit/ObjectiveGit.h>

// Swift requires that raw values be literals, so this needs to be a C enum.
typedef NS_ENUM(NSUInteger, XitChange) {
  XitChangeUnmodified = GIT_DELTA_UNMODIFIED,
  XitChangeAdded = GIT_DELTA_ADDED,
  XitChangeDeleted = GIT_DELTA_DELETED,
  XitChangeModified = GIT_DELTA_MODIFIED,
  XitChangeRenamed = GIT_DELTA_RENAMED,
  XitChangeCopied = GIT_DELTA_COPIED,
  XitChangeIgnored = GIT_DELTA_IGNORED,
  XitChangeUntracked = GIT_DELTA_UNTRACKED,
  XitChangeTypeChange = GIT_DELTA_TYPECHANGE,
  XitChangeConflict = GIT_DELTA_CONFLICTED,
  XitChangeMixed,  // For folders containing a mix of changes
};
