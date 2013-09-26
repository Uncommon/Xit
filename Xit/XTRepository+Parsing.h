#import "XTRepository.h"

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

@class GTSubmodule;

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
- (NSDictionary*)attibutesForCommit:(NSString*)ref;

- (BOOL)stageFile:(NSString*)file;
- (BOOL)unstageFile:(NSString*)file;

- (BOOL)commitWithMessage:(NSString*)message
                    amend:(BOOL)amend
              outputBlock:(void (^)(NSString *output))outputBlock
                    error:(NSError**)error;

- (NSArray*)fileNamesForRef:(NSString*)ref;

@end
