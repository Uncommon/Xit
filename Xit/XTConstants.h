typedef enum {
  XTRefTypeBranch,
  XTRefTypeActiveBranch,
  XTRefTypeRemoteBranch,
  XTRefTypeTag,
  XTRefTypeRemote,
  XTRefTypeUnknown
} XTRefType;

typedef enum {
  XTBranchesGroupIndex,
  XTRemotesGroupIndex,
  XTTagsGroupIndex,
  XTStashesGroupIndex,
  XTSubmodulesGroupIndex,
} XTSideBarRootItems;

typedef enum {
  XTErrorWriteLock = 1
} XTError;

extern NSString *XTErrorDomainXit, *XTErrorDomainGit;

/// Fake value for seleting staging view.
extern NSString * const XTStagingSHA;

/// The repository's index has changed.
extern NSString * const XTRepositoryIndexChangedNotification;
