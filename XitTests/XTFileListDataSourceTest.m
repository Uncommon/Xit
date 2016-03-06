#import "XTTest.h"
#import "XTHistoryDataSource.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTFileListDataSource.h"
#import "XTHistoryItem.h"
#include "XTQueueUtils.h"

@interface XTFileListDataSourceTest : XTTest

@end

@implementation XTFileListDataSourceTest

- (XTHistoryDataSource*)makeDataSource
{
  XTHistoryDataSource *hds = [[XTHistoryDataSource alloc] init];

  [hds setRepo:repository];
  [self waitForRepoQueue];
  // Part of the reload process is dispatched to the main queue.
  WaitForQueue(dispatch_get_main_queue());
  return hds;
}

- (void)testHistoricFileList
{
  NSString *text = @"some text";

  for (int n = 0; n < 10; n++) {
    NSString *file = [NSString stringWithFormat:@"%@/file_%u.txt", repoPath, n];

    [text writeToFile:file
           atomically:YES
             encoding:NSASCIIStringEncoding
                error:nil];
    [repository stageAllFiles];
    [repository commitWithMessage:@"commit"
                            amend:NO
                      outputBlock:NULL
                            error:NULL];
  }

  XTHistoryDataSource *hds = [self makeDataSource];
  NSInteger expectedFileCount = 11;

  for (XTHistoryItem *item in hds.items) {
    repository.selectedCommit = item.sha;

    XTFileListDataSource *flds = [[XTFileListDataSource alloc] init];
    flds.repository = repository;
    [self waitForRepoQueue];

    const NSInteger fileCount =
        [flds outlineView:nil numberOfChildrenOfItem:nil];

    XCTAssertEqual(fileCount, expectedFileCount, @"file count");
    --expectedFileCount;
  }
}

- (void)testMultipleFileList
{
  NSString *text = @"some text";

  for (int i = 0; i < 2; ++i)
    for (int j = 0; j < 3; ++j) {
      NSString *path = [NSString stringWithFormat:@"dir_%d/subdir_%d", i, j];
      NSString *fullPath = [repoPath stringByAppendingPathComponent:path];
    
      NSLog(@"create path %@", path);
      [[NSFileManager defaultManager] createDirectoryAtPath:fullPath
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:NULL];
    }
  [[NSFileManager defaultManager] removeItemAtPath:file1Path error:NULL];

  for (int n = 0; n < 12; ++n) {
    NSString *file =
        [NSString stringWithFormat:@"%@/dir_%d/subdir_%d/file_%d.txt",
                                   repoPath, n % 2, n % 3, n];
    [text writeToFile:file
           atomically:YES
             encoding:NSASCIIStringEncoding
                error:nil];
  }
  [repository stageAllFiles];
  [repository commitWithMessage:@"commit"
                          amend:NO
                    outputBlock:NULL
                          error:NULL];

  XTHistoryDataSource *hds = [self makeDataSource];
  XTHistoryItem *item = (XTHistoryItem *)(hds.items)[0];
  repository.selectedCommit = item.sha;

  XTFileListDataSource *flds = [[XTFileListDataSource alloc] init];

  flds.repository = repository;
  [self waitForRepoQueue];

  const NSInteger fileCount = [flds outlineView:nil numberOfChildrenOfItem:nil];
  XCTAssertEqual(fileCount, 3L); // 2 folders plus deleted file1.txt

  for (int rootIndex = 0; rootIndex < 2; ++rootIndex) {
    NSTreeNode *root = [flds outlineView:nil child:rootIndex ofItem:nil];
    const NSInteger rnf = [flds outlineView:nil numberOfChildrenOfItem:root];

    XCTAssertEqual(rnf, 3L);
  }
}

@end
