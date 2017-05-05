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

@class XTDiffDelta;
@class XTFileChange;


@interface XTRepository (Reading)

- (BOOL)stageFile:(NSString*)file error:(NSError**)error;
- (BOOL)stageAllFilesWithError:(NSError**)error;
- (BOOL)unstageFile:(NSString*)file error:(NSError**)error;

- (BOOL)commitWithMessage:(NSString*)message
                    amend:(BOOL)amend
              outputBlock:(nullable void (^)(NSString *output))outputBlock
                    error:(NSError**)error;

- (nullable XTDiffDelta*)diffForFile:(NSString*)path
                           commitSHA:(NSString*)sha
                           parentSHA:(nullable NSString*)parentSHA;

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

NS_ASSUME_NONNULL_END
