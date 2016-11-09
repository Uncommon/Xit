#import "XTTest.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTFileTreeDataSource.h"
#include "XTQueueUtils.h"
#import "Xit-Swift.h"

@interface XTFileListDataSourceTest : XTTest

@end


@implementation XTFileListDataSourceTest

- (void)testHistoricFileList
{
  NSString *text = @"some text";
  NSError *error;

  for (int n = 0; n < 10; n++) {
    NSString *fileName = [NSString stringWithFormat:@"file_%u.txt", n];
    NSString *filePath = [self.repoPath stringByAppendingPathComponent:fileName];

    error = nil;
    [text writeToFile:filePath
           atomically:YES
             encoding:NSASCIIStringEncoding
                error:&error];
    XCTAssertNil(error);
    [self.repository stageAllFilesWithError:&error];
    XCTAssertNil(error);
    [self.repository commitWithMessage:@"commit"
                                 amend:NO
                           outputBlock:NULL
                                 error:&error];
    XCTAssertNil(error);
  }

  NSOutlineView *outlineView = [[NSOutlineView alloc] init];
  XTFakeWinController *winController = [[XTFakeWinController alloc] init];
  XTFileTreeDataSource *flds = [[XTFileTreeDataSource alloc] init];
  NSInteger expectedFileCount = 11;
  XTCommitHistory *history = [[XTCommitHistory alloc] init];

  flds.winController = (XTWindowController*)winController;
  flds.repository = self.repository;
  history.repository = self.repository;
  [self waitForRepoQueue];

  for (CommitEntry *entry in history.entries) {
    winController.selectedModel =
        [[XTCommitChanges alloc] initWithRepository:self.repository
                                                sha:entry.commit.sha];
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
  NSError *error = nil;

  for (int i = 0; i < 2; ++i)
    for (int j = 0; j < 3; ++j) {
      NSString *path = [NSString stringWithFormat:@"dir_%d/subdir_%d", i, j];
      NSString *fullPath = [self.repoPath stringByAppendingPathComponent:path];
    
      NSLog(@"create path %@", path);
      [[NSFileManager defaultManager] createDirectoryAtPath:fullPath
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:&error];
      XCTAssertNil(error);
    }
  [[NSFileManager defaultManager] removeItemAtPath:self.file1Path error:&error];
  XCTAssertNil(error);

  for (int n = 0; n < 12; ++n) {
    NSString *file =
        [NSString stringWithFormat:@"%@/dir_%d/subdir_%d/file_%d.txt",
                                   self.repoPath, n % 2, n % 3, n];
    [text writeToFile:file
           atomically:YES
             encoding:NSASCIIStringEncoding
                error:nil];
  }
  [self.repository stageAllFilesWithError:&error];
  [self.repository commitWithMessage:@"commit"
                               amend:NO
                         outputBlock:NULL
                               error:&error];

  XTFakeWinController *winController = [[XTFakeWinController alloc] init];

  winController.selectedModel = [[XTCommitChanges alloc]
      initWithRepository:self.repository sha:[self.repository headSHA]];

  NSOutlineView *outlineView = [[NSOutlineView alloc] init];
  XTFileTreeDataSource *flds = [[XTFileTreeDataSource alloc] init];

  flds.winController = (XTWindowController*)winController;
  flds.repository = self.repository;
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
