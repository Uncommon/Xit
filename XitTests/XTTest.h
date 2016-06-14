#import <XCTest/XCTest.h>

@class XTRepository;
@protocol XTFileChangesModel;

@interface XTTest : XCTestCase {
}

@property NSString *repoPath, *remoteRepoPath, *file1Name, *file1Path;
@property XTRepository *repository, *remoteRepository;

- (XTRepository *)createRepo:(NSString *)repoName;
- (void)makeRemoteRepo;
- (void)waitForRepoQueue;
- (void)addInitialRepoContent;
- (BOOL)writeText:(NSString*)text toFile:(NSString*)path;
- (BOOL)writeTextToFile1:(NSString *)text;
- (BOOL)commitNewTextFile:(NSString *)name content:(NSString *)content;
- (BOOL)commitNewTextFile:(NSString *)name
                  content:(NSString *)content
             inRepository:(XTRepository *)repo;

@end


@interface XTFakeWinController : NSObject

@property NSString *selectedCommitSHA;
@property id<XTFileChangesModel> selectedModel;

@end
