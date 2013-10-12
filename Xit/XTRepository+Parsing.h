#import "XTRepository.h"
#import <ObjectiveGit/ObjectiveGit.h>

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
  XitChangeMixed,  // For folders containing a mix of changes
} XitChange;

@class GTSubmodule;
@class XTDiffDelta;

#import <Cocoa/Cocoa.h>
@interface XTRepository (Reading)

- (BOOL)
    readRefsWithLocalBlock:(void (^)(NSString *name, NSString *commit))localBlock
               remoteBlock:(void (^)(NSString *remoteName, NSString *branchName,
                                     NSString *commit))remoteBlock
                  tagBlock:(void (^)(NSString *name, NSString *commit))tagBlock;
- (BOOL)
    readStagedFilesWithBlock:(void (^)(NSString *name, NSString *status))block;
- (BOOL)readUnstagedFilesWithBlock:(void (^)(NSString *name, NSString *status))
                                   block;
- (BOOL)readStashesWithBlock:(void (^)(NSString *commit, NSString *name))block;
- (BOOL)readSubmodulesWithBlock:(void (^)(GTSubmodule *sub))block;
- (BOOL)parseCommit:(NSString*)ref
         intoHeader:(NSDictionary**)header
            message:(NSString**)message
              files:(NSArray**)files;

- (BOOL)stageFile:(NSString*)file;
- (BOOL)stageAllFiles;
- (BOOL)unstageFile:(NSString*)file;

- (BOOL)commitWithMessage:(NSString*)message
                    amend:(BOOL)amend
              outputBlock:(void (^)(NSString *output))outputBlock
                    error:(NSError**)error;

- (NSArray*)fileNamesForRef:(NSString*)ref;
- (NSArray*)changesForRef:(NSString*)ref parent:(NSString*)parentSHA;
- (XTDiffDelta*)diffForFile:(NSString*)path
                  commitSHA:(NSString*)sha
                  parentSHA:(NSString*)parentSHA;

@end

#import <Cocoa/Cocoa.h>
@interface XTFileChange : NSObject

@property NSString *path;
@property XitChange change;

@end


@interface XTDiffDelta : GTDiffDelta

@end
