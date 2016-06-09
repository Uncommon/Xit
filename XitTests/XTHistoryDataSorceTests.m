#import "XTTest.h"
#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTHistoryDataSource.h"
#import "XTHistoryItem.h"
#include "XTQueueUtils.h"

@interface XTHistoryDataSorceTests : XTTest

@end

@implementation XTHistoryDataSorceTests

- (XTHistoryDataSource*)makeDataSource
{
  XTHistoryDataSource *result = [[XTHistoryDataSource alloc] init];

  [result setRepo:repository];
  [self waitForRepoQueue];
  return result;
}

- (void)testRootCommitsGraph
{
  const NSInteger nCommits = 15;
  NSFileManager *fileManager = [NSFileManager defaultManager];

  for (int n = 0; n < nCommits; n++) {
    if ((n % 5) == 0) {
      // Every 5th commit, create a new root commit
      NSString *rootName = [NSString stringWithFormat:@"refs/heads/root_%d", n];
      NSData *data;
      
      data = [repository executeGitWithArgs:@[ @"symbolic-ref",
                                               @"HEAD", rootName ]
                                     writes:NO
                                      error:nil];
      if (data == nil)
        XCTFail(@"'%@' error", rootName);
      
      // Recursively unstage the current directory
      data = [repository executeGitWithArgs:@[ @"rm", @"--cached", @"-r", @"." ]
                                     writes:NO
                                      error:nil];
      if (data == nil)
        XCTFail(@"'%@' error", rootName);
      
      // Delete all untracked files
      data = [repository executeGitWithArgs:@[ @"clean", @"-f", @"-d" ]
                                     writes:NO
                                      error:nil];
      if (data == nil)
        XCTFail(@"'%@' error", rootName);
    }

    NSString *testFilePath =
        [NSString stringWithFormat:@"%@/file%d.txt", repoPath, n];
    NSString *txt = [NSString stringWithFormat:@"some text %d", n];
    [txt writeToFile:testFilePath
          atomically:YES
            encoding:NSASCIIStringEncoding
               error:nil];

    if (![fileManager fileExistsAtPath:testFilePath]) {
      XCTFail(@"testFile NOT Found!!");
    }
    if (![repository stageFile:testFilePath.lastPathComponent]) {
      XCTFail(@"add file '%@'", testFilePath);
    }
    if (![repository commitWithMessage:[NSString stringWithFormat:@"new %@",
                                                                  testFilePath]
                                 amend:NO
                           outputBlock:NULL
                                 error:NULL]) {
      XCTFail(@"Commit with mesage 'new %@'", testFilePath);
    }
  }

  XTHistoryDataSource *hds = [self makeDataSource];

  for (NSUInteger idx = 0; idx < hds.shas.count; ++idx) {
    XTHistoryItem *item = [hds itemAtIndex:idx];

    if (idx == (hds.shas.count - 1)) {
      XCTAssertEqual(item.lineInfo.numColumns, 0);
    } else {
      XCTAssertEqual(item.lineInfo.numColumns, 1, "item %lu", idx);
    }
  };
}

- (void)testXTHistoryDataSource
{
  const NSUInteger nCommits = 60;
  NSFileManager *defaultManager = [NSFileManager defaultManager];

  for (int n = 0; n < nCommits; n++) {
    NSString *bn = [NSString stringWithFormat:@"branch_%d", n];
    if ((n % 10) == 0) {
      [repository checkout:@"master" error:NULL];
      if (![repository createBranch:bn]) {
        XCTFail(@"Create Branch");
      }
    }

    NSString *testFile =
        [NSString stringWithFormat:@"%@/file%d.txt", repoPath, n];
    NSString *txt = [NSString stringWithFormat:@"some text %d", n];

    [txt writeToFile:testFile
          atomically:YES
            encoding:NSASCIIStringEncoding
               error:nil];

    XCTAssertTrue([defaultManager fileExistsAtPath:testFile]);
    if (![repository stageFile:testFile.lastPathComponent]) {
      XCTFail(@"add file '%@'", testFile);
    }
    if (![repository commitWithMessage:[NSString stringWithFormat:@"new %@",
                                                                  testFile]
                                 amend:NO
                           outputBlock:NULL
                                 error:NULL]) {
      XCTFail(@"Commit with mesage 'new %@'", testFile);
    }
  }

  NSTableView *tableView = [[NSTableView alloc] init];
  XTHistoryDataSource *hds = [self makeDataSource];
  const NSUInteger nc = [hds numberOfRowsInTableView:tableView];

  XCTAssertEqual(nc, nCommits + 1, @"wrong commit count");
}

@end
