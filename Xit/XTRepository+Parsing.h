//
//  XTRepository+Parsing.h
//  Xit
//
//  Created by David Catmull on 7/13/12.
//

#import "XTRepository.h"


extern NSString *XTHeaderNameKey;
extern NSString *XTHeaderContentKey;

extern NSString
        *XTCommitSHAKey,
        *XTTreeSHAKey,
        *XTParentSHAsKey,
        *XTRefsKey,
        *XTAuthorNameKey,
        *XTAuthorEmailKey,
        *XTAuthorDateKey,
        *XTCommitterNameKey,
        *XTCommitterEmailKey,
        *XTCommitterDateKey;

@interface XTRepository (Reading)

- (BOOL)readRefsWithLocalBlock:(void (^)(NSString *name, NSString *commit))localBlock
                   remoteBlock:(void (^)(NSString *remoteName, NSString *branchName, NSString *commit))remoteBlock
                      tagBlock:(void (^)(NSString *name, NSString *commit))tagBlock;
- (BOOL)readStagedFilesWithBlock:(void (^)(NSString *name, NSString *status))block;
- (BOOL)readUnstagedFilesWithBlock:(void (^)(NSString *name, NSString *status))block;
- (BOOL)readStashesWithBlock:(void (^)(NSString *commit, NSString *name))block;
- (BOOL)parseCommit:(NSString *)ref intoHeader:(NSDictionary **)header message:(NSString **)message files:(NSArray **)files;

- (BOOL)stageFile:(NSString *)file;
- (BOOL)unstageFile:(NSString *)file;

- (NSString *)diffForStagedFile:(NSString *)file;
- (NSString *)diffForUnstagedFile:(NSString *)file;

- (NSArray *)fileNamesForRef:(NSString *)ref;

@end
