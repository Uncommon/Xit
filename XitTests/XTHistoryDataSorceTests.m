#import "XTTest.h"
#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTHistoryDataSource.h"
#import "XTHistoryItem.h"

#import <Cocoa/Cocoa.h>
@interface XTHistoryDataSorceTests : XTTest

@end

@implementation XTHistoryDataSorceTests

- (void)testRootCommitsGraph
{
  NSInteger nCommits = 15;
  NSFileManager *defaultManager = [NSFileManager defaultManager];

  for (int n = 0; n < nCommits; n++) {
    NSString *rn = [NSString stringWithFormat:@"refs/heads/root_%d", n];
    if ((n % 5) == 0) {
      NSData *data =
          [repository executeGitWithArgs:@[ @"symbolic-ref", @"HEAD", rn ]
                                  writes:NO
                                   error:nil];
      if (data == nil) {
        STFail(@"'%@' error", rn);
      }
      data = [repository executeGitWithArgs:@[ @"rm", @"--cached", @"-r", @"." ]
                                     writes:NO
                                      error:nil];
      if (data == nil) {
        STFail(@"'%@' error", rn);
      }
      data = [repository executeGitWithArgs:@[ @"clean", @"-f", @"-d" ]
                                     writes:NO
                                      error:nil];
      if (data == nil) {
        STFail(@"'%@' error", rn);
      }
    }

    NSString *testFile =
        [NSString stringWithFormat:@"%@/file%d.txt", repoPath, n];
    NSString *txt = [NSString stringWithFormat:@"some text %d", n];
    [txt writeToFile:testFile
          atomically:YES
            encoding:NSASCIIStringEncoding
               error:nil];

    if (![defaultManager fileExistsAtPath:testFile]) {
      STFail(@"testFile NOT Found!!");
    }
    if (![repository stageFile:[testFile lastPathComponent]]) {
      STFail(@"add file '%@'", testFile);
    }
    if (![repository commitWithMessage:[NSString stringWithFormat:@"new %@",
                                                                  testFile]
                                 amend:NO
                           outputBlock:NULL
                                 error:NULL]) {
      STFail(@"Commit with mesage 'new %@'", testFile);
    }
  }

  XTHistoryDataSource *hds = [[XTHistoryDataSource alloc] init];
  [hds setRepo:repository];
  [self waitForRepoQueue];

  NSArray *items = hds.items;

  [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    XTHistoryItem *item = (XTHistoryItem *)obj;

    if (idx != (items.count - 1)) {
      STAssertTrue(item.lineInfo.numColumns == 1,
                   @"%lu - incorrect numColumns=%lu", idx,
                   item.lineInfo.numColumns);
    } else {
      STAssertTrue(item.lineInfo.numColumns == 0,
                   @"%lu - incorrect numColumns=%lu", idx,
                   item.lineInfo.numColumns);
    }
  }];
}

- (void)testXTHistoryDataSource
{
  NSInteger nCommits = 60;
  NSFileManager *defaultManager = [NSFileManager defaultManager];

  for (int n = 0; n < nCommits; n++) {
    NSString *bn = [NSString stringWithFormat:@"branch_%d", n];
    if ((n % 10) == 0) {
      [repository checkout:@"master" error:NULL];
      if (![repository createBranch:bn]) {
        STFail(@"Create Branch");
      }
    }

    NSString *testFile =
        [NSString stringWithFormat:@"%@/file%d.txt", repoPath, n];
    NSString *txt = [NSString stringWithFormat:@"some text %d", n];
    [txt writeToFile:testFile
          atomically:YES
            encoding:NSASCIIStringEncoding
               error:nil];

    if (![defaultManager fileExistsAtPath:testFile]) {
      STFail(@"testFile NOT Found!!");
    }
    if (![repository stageFile:[testFile lastPathComponent]]) {
      STFail(@"add file '%@'", testFile);
    }
    if (![repository commitWithMessage:[NSString stringWithFormat:@"new %@",
                                                                  testFile]
                                 amend:NO
                           outputBlock:NULL
                                 error:NULL]) {
      STFail(@"Commit with mesage 'new %@'", testFile);
    }
  }

  XTHistoryDataSource *hds = [[XTHistoryDataSource alloc] init];
  [hds setRepo:repository];
  [self waitForRepoQueue];

  NSUInteger nc = [hds numberOfRowsInTableView:nil];
  STAssertTrue((nc == (nCommits + 1)), @"found %d commits", nc);
}

@end
