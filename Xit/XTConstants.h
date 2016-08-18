#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSUInteger, XTRefType) {
  XTRefTypeBranch,
  XTRefTypeActiveBranch,
  XTRefTypeRemoteBranch,
  XTRefTypeTag,
  XTRefTypeRemote,
  XTRefTypeUnknown
};

typedef NS_ENUM(NSInteger, XTGroupIndex) {
  XTGroupIndexWorkspace,
  XTGroupIndexBranches,
  XTGroupIndexRemotes,
  XTGroupIndexTags,
  XTGroupIndexStashes,
  XTGroupIndexSubmodules,
};

typedef NS_ENUM(NSUInteger, XTError) {
  XTErrorWriteLock = 1,
  XTErrorUnexpectedObject,
};

extern NSString *XTErrorDomainXit, *XTErrorDomainGit;

/// Fake value for seleting staging view.
extern NSString * const XTStagingSHA;

/// The repository's index has changed.
extern NSString * const XTRepositoryIndexChangedNotification;

extern NSString * const XTTaskStartedNotification;
extern NSString * const XTTaskEndedNotification;
