#import <SenTestingKit/SenTestingKit.h>

@class XTRepository;

@interface XTTest : SenTestCase {
  NSString *repoPath;
  NSString *remoteRepoPath;
  NSString *file1Path;
  XTRepository *repository, *remoteRepository;
}

- (XTRepository *)createRepo:(NSString *)repoName;
- (void)makeRemoteRepo;
- (void)waitForRepoQueue;
- (void)addInitialRepoContent;
- (BOOL)writeTextToFile1:(NSString *)text;
- (BOOL)commitNewTextFile:(NSString *)name content:(NSString *)content;
- (BOOL)commitNewTextFile:(NSString *)name
                  content:(NSString *)content
             inRepository:(XTRepository *)repo;

@end
