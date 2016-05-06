#import "XTTest.h"
#import "XTHistoryDataSource.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTFileTreeDataSource.h"
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
    NSString *fileName = [NSString stringWithFormat:@"file_%u.txt", n];
    NSString *filePath = [repoPath stringByAppendingPathComponent:fileName];

    [text writeToFile:filePath
           atomically:YES
             encoding:NSASCIIStringEncoding
                error:nil];
    [repository stageAllFiles];
    [repository commitWithMessage:@"commit"
                            amend:NO
                      outputBlock:NULL
                            error:NULL];
  }

  NSOutlineView *outlineView = [[NSOutlineView alloc] init];
  XTFakeDocController *docController = [[XTFakeDocController alloc] init];
  XTHistoryDataSource *hds = [self makeDataSource];
  XTFileTreeDataSource *flds = [[XTFileTreeDataSource alloc] init];
  NSInteger expectedFileCount = 11;

  hds.controller = (XTDocController*)docController;
  flds.docController = (XTDocController*)docController;
  [hds setRepo:repository];
  flds.repository = repository;
  [self waitForRepoQueue];

  for (XTHistoryItem *item in hds.items) {
    docController.selectedCommitSHA = item.sha;
    [flds reload];
    [self waitForRepoQueue];

    const NSInteger fileCount =
        [flds outlineView:outlineView numberOfChildrenOfItem:nil];

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

  XTFakeDocController *docController = [[XTFakeDocController alloc] init];
  XTHistoryDataSource *hds = [self makeDataSource];
  XTHistoryItem *item = (XTHistoryItem *)(hds.items)[0];

  [hds setController:(XTDocController*)docController];
  docController.selectedCommitSHA = item.sha;

  NSOutlineView *outlineView = [[NSOutlineView alloc] init];
  XTFileTreeDataSource *flds = [[XTFileTreeDataSource alloc] init];

  flds.repository = repository;
  [self waitForRepoQueue];

  const NSInteger fileCount = [flds outlineView:outlineView
                         numberOfChildrenOfItem:nil];
  XCTAssertEqual(fileCount, 3L); // 2 folders plus deleted file1.txt

  for (int rootIndex = 0; rootIndex < 2; ++rootIndex) {
    NSTreeNode *root = [flds outlineView:outlineView child:rootIndex ofItem:nil];
    const NSInteger rnf =
        [flds outlineView:outlineView numberOfChildrenOfItem:root];

    XCTAssertEqual(rnf, 3L, @"item %i", rootIndex);
  }
}

@end
