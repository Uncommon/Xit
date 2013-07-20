#import <Foundation/Foundation.h>
#import "XTRepository.h"

@interface XTRepository (Commands)

- (BOOL)initializeRepository;
- (BOOL)createBranch:(NSString *)name;
- (BOOL)deleteBranch:(NSString *)name error:(NSError **)error;
- (NSString *)currentBranch;
- (BOOL)commitWithMessage:(NSString *)message;
- (BOOL)createTag:(NSString *)name withMessage:(NSString *)msg;
- (BOOL)deleteTag:(NSString *)name error:(NSError **)error;
- (BOOL)addRemote:(NSString *)name withUrl:(NSString *)url;
- (BOOL)deleteRemote:(NSString *)name error:(NSError **)error;
- (BOOL)push:(NSString *)remote;
- (BOOL)checkout:(NSString *)branch error:(NSError **)error;
- (BOOL)merge:(NSString *)name error:(NSError **)error;

- (NSString *)diffForStagedFile:(NSString *)file;
- (NSString *)diffForUnstagedFile:(NSString *)file;
- (NSString *)diffForCommit:(NSString *)sha;

- (BOOL)stagePatch:(NSString *)patch;
- (BOOL)unstagePatch:(NSString *)patch;
- (BOOL)discardPatch:(NSString *)patch;

- (BOOL)renameBranch:(NSString *)branch to:(NSString *)newName;
- (BOOL)renameTag:(NSString *)branch to:(NSString *)newName;
- (BOOL)renameRemote:(NSString *)branch to:(NSString *)newName;

- (BOOL)saveStash:(NSString *)name;
- (BOOL)popStash:(NSString *)name error:(NSError **)error;
- (BOOL)applyStash:(NSString *)name error:(NSError **)error;
- (BOOL)dropStash:(NSString *)name error:(NSError **)error;

@end
