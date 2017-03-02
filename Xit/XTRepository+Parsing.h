#import "XTRepository.h"
#import <ObjectiveGit/ObjectiveGit.h>

NS_ASSUME_NONNULL_BEGIN

// Values used by changesForRef:
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

@class GTSubmodule;
@class XTDiffDelta;
@class XTFileChange;
@class XTLocalBranch;
@class XTRemote;
@class XTStash;
@class XTSubmodule;
@class XTTag;
@class XTWorkspaceFileStatus;


@interface XTRepository (Reading)

/// A dictionary mapping paths to XTWorkspaceFileStatuses.
@property (readonly, copy) NSDictionary<NSString*, XTWorkspaceFileStatus*>
    *workspaceStatus;

- (BOOL)stageFile:(NSString*)file error:(NSError**)error;
- (BOOL)stageAllFilesWithError:(NSError**)error;
- (BOOL)unstageFile:(NSString*)file error:(NSError**)error;

- (BOOL)commitWithMessage:(NSString*)message
                    amend:(BOOL)amend
              outputBlock:(nullable void (^)(NSString *output))outputBlock
                    error:(NSError**)error;

/// Returns a list of changed files in the given commit.
- (nullable NSArray<XTFileChange*>*)changesForRef:(NSString*)ref
                                           parent:(nullable NSString*)parentSHA;
- (nullable XTDiffDelta*)diffForFile:(NSString*)path
                           commitSHA:(NSString*)sha
                           parentSHA:(nullable NSString*)parentSHA;
- (BOOL)isTextFile:(NSString*)path commit:(NSString*)commit;

- (nullable XTRemote*)remoteWithName:(NSString*)name error:(NSError**)error
    NS_SWIFT_NAME(remote(_:));

@end


/// Represents a changed file from a commit.
@interface XTFileChange : NSObject

/// The item's path relative to the repository.
@property NSString *path;
/// The (staged) change status.
@property XitChange change;
/// The unstaged change status, if applicable.
@property XitChange unstagedChange;

- (instancetype)initWithPath:(NSString*)path;
- (instancetype)initWithPath:(NSString*)path
                      change:(XitChange)change;
- (instancetype)initWithPath:(NSString*)path
                      change:(XitChange)change
              unstagedChange:(XitChange)unstagedChange;

@end


/// Contains the stanged and unstaged status for a workspace file.
@interface XTWorkspaceFileStatus : NSObject

@property XitChange change;
@property XitChange unstagedChange;

@end


/// Represents a workspace file with staged or unstaged changes.
@interface XTFileStaging : XTFileChange

/// The new path for a moved file.
@property NSString *destinationPath;

@end


@interface XTDiffDelta : GTDiffDelta

@end

NS_ASSUME_NONNULL_END
