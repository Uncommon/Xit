#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@class XTRepository;

@interface XTTest : XCTestCase {
}

@property NSString *repoPath, *remoteRepoPath;
@property (readonly) NSString
    *file1Name, *file1Path,
    *addedName, *untrackedName;
@property XTRepository *repository, *remoteRepository;

- (nullable XTRepository*)createRepo:(NSString*)repoName;
- (void)makeRemoteRepo;
- (void)waitForRepository:(XTRepository*)repo;
- (void)waitForRepoQueue;
- (void)addInitialRepoContent;
- (void)makeStash;
- (BOOL)writeText:(NSString*)text toFile:(NSString*)path;
- (BOOL)writeText:(NSString*)text
           toFile:(NSString*)path
       repository:(XTRepository*)repository;
- (BOOL)writeTextToFile1:(NSString *)text;
- (BOOL)commitNewTextFile:(NSString *)name content:(NSString *)content;
- (BOOL)commitNewTextFile:(NSString *)name
                  content:(NSString *)content
             inRepository:(XTRepository *)repo
        NS_SWIFT_NAME(commit(newTextFile:content:repository:));

@end

NS_ASSUME_NONNULL_END
