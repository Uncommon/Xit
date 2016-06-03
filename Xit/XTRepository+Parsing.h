#import "XTRepository.h"
#import <ObjectiveGit/ObjectiveGit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *XTHeaderNameKey;
extern NSString *XTHeaderContentKey;

extern NSString *XTCommitSHAKey,
    *XTTreeSHAKey,
    *XTParentSHAsKey,
    *XTRefsKey,
    *XTAuthorNameKey,
    *XTAuthorEmailKey,
    *XTAuthorDateKey,
    *XTCommitterNameKey,
    *XTCommitterEmailKey,
    *XTCommitterDateKey;

// Values used by changesForRef:
typedef enum {
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
} XitChange;

@class GTSubmodule;
@class XTDiffDelta;
@class XTFileChange;

@interface XTRepository (Reading)

- (BOOL)
    readRefsWithLocalBlock:(void (^)(NSString *name, NSString *commit))localBlock
               remoteBlock:(void (^)(NSString *remoteName, NSString *branchName,
                                     NSString *commit))remoteBlock
                  tagBlock:(void (^)(NSString *name, NSString *commit))tagBlock;
/// Returns a dictionary mapping paths to XTWorkspaceFileStatuses.
- (NSDictionary*)workspaceStatus;
- (BOOL)readStashesWithBlock:(void (^)(NSString *commit, NSString *name))block;
- (BOOL)readSubmodulesWithBlock:(void (^)(GTSubmodule *sub))block;
- (BOOL)parseCommit:(NSString*)ref
         intoHeader:(NSDictionary * _Nullable * _Nonnull)header
            message:(NSString * _Nullable * _Nonnull)message
              files:(NSArray * _Nullable * _Nullable)files;

- (BOOL)stageFile:(NSString*)file;
- (BOOL)stageAllFiles;
- (BOOL)unstageFile:(NSString*)file;

- (BOOL)commitWithMessage:(NSString*)message
                    amend:(BOOL)amend
              outputBlock:(nullable void (^)(NSString *output))outputBlock
                    error:(NSError**)error;

- (NSArray*)fileNamesForRef:(NSString*)ref;
/// Returns a list of changed files in the given commit.
- (NSArray<XTFileChange*>*)changesForRef:(NSString*)ref
                                  parent:(nullable NSString*)parentSHA;
- (GTCommit*)commitForStashAtIndex:(NSUInteger)index;
- (XTDiffDelta*)diffForFile:(NSString*)path
                  commitSHA:(NSString*)sha
                  parentSHA:(nullable NSString*)parentSHA;
- (XTDiffDelta*)stagedDiffForFile:(NSString*)path;
- (XTDiffDelta*)unstagedDiffForFile:(NSString*)path;
- (BOOL)isTextFile:(NSString*)path commit:(NSString*)commit;

@end


/// Represents a changed file from a commit.
@interface XTFileChange : NSObject

@property NSString *path;
@property XitChange change;
@property XitChange unstagedChange;

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
