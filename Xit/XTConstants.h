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
extern NSString * const XTStagingSHA;  // Fake value for seleting staging view
