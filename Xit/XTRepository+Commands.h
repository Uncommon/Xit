#import <Foundation/Foundation.h>
#import "XTRepository.h"

NS_ASSUME_NONNULL_BEGIN

@interface XTRepository (Commands)

@property (readonly) NSString * _Nullable currentBranch;

- (BOOL)initializeRepository;
- (BOOL)createBranch:(NSString*)name;
- (BOOL)deleteBranch:(NSString*)name error:(NSError**)error;
- (nullable NSString*)currentBranch;
- (BOOL)createTag:(NSString*)name targetSHA:(NSString*)sha message:(NSString*)msg;
- (BOOL)createLightweightTag:(NSString*)name targetSHA:(NSString*)sha;
- (BOOL)deleteTag:(NSString*)name error:(NSError**)error;
- (BOOL)addRemote:(NSString*)name withUrl:(NSString*)url;
- (BOOL)deleteRemote:(NSString*)name error:(NSError**)error;
- (BOOL)push:(NSString*)remote;
- (BOOL)checkout:(NSString*)branch error:(NSError**)error;
- (BOOL)merge:(NSString*)name error:(NSError**)error;

- (BOOL)stagePatch:(NSString*)patch;
- (BOOL)unstagePatch:(NSString*)patch;
- (BOOL)discardPatch:(NSString*)patch;
- (BOOL)unstageAllFiles;

- (BOOL)renameRemote:(NSString*)branch to:(NSString*)newName;
- (NSString*)urlStringForRemote:(NSString*)remoteName;

- (BOOL)saveStash:(nullable NSString*)name includeUntracked:(BOOL)untracked;
- (BOOL)popStashIndex:(NSUInteger)index error:(NSError**)error;
- (BOOL)applyStashIndex:(NSUInteger)index error:(NSError**)error;
- (BOOL)dropStashIndex:(NSUInteger)index error:(NSError**)error;

- (BOOL)addSubmoduleAtPath:(NSString*)path
                 urlOrPath:(NSString*)urlOrPath
                     error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
