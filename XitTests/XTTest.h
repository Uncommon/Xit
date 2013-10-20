#import <SenTestingKit/SenTestingKit.h>

@class XTRepository;

#import <Cocoa/Cocoa.h>
@interface XTTest : SenTestCase {
  NSString *repoPath;
  NSString *remoteRepoPath;
  NSString *file1Path;
  XTRepository *repository, *remoteRepository;
  BOOL reloadDetected;
}

- (XTRepository *)createRepo:(NSString *)repoName;
- (void)makeRemoteRepo;
- (void)waitForQueue:(dispatch_queue_t)queue;
- (void)waitForRepoQueue;
- (void)addInitialRepoContent;
- (BOOL)writeTextToFile1:(NSString *)text;
- (BOOL)commitNewTextFile:(NSString *)name content:(NSString *)content;
- (BOOL)commitNewTextFile:(NSString *)name
                  content:(NSString *)content
             inRepository:(XTRepository *)repo;

@end
