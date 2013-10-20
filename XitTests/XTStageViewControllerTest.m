#import "XTTest.h"
#import "XTHTML.h"
#import "XTUnstagedDataSource.h"
#import "XTStagedDataSource.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTFileIndexInfo.h"
#import "XTStageViewController.h"

#import <OCMock/OCMock.h>

#import <Cocoa/Cocoa.h>
@interface XTStageViewControllerTest : XTTest

@end

#import <Cocoa/Cocoa.h>
@interface XTStageViewController (Test)

@property(readwrite) XTStagedDataSource *stageDS;
@property(readwrite) XTUnstagedDataSource *unstageDS;
@property(readwrite) NSTableView *unstageTable;

@end


@implementation XTStageViewControllerTest

- (void)addInitialRepoContent
{
  // Do nothing by default
}

- (void)doStageUnstage
{
  NSString *path1 = [NSString stringWithFormat:@"%@/fileA.txt", repoPath];
  NSString *path2 = [NSString stringWithFormat:@"%@/fileB.txt", repoPath];
  NSError *error = nil;

  [@"text1" writeToFile:path1
             atomically:YES
               encoding:NSASCIIStringEncoding
                  error:&error];
  STAssertNil(error, @"creating file1");
  [@"text2" writeToFile:path2
             atomically:YES
               encoding:NSASCIIStringEncoding
                  error:&error];
  STAssertNil(error, @"creating file2");

  id mockUnstagedTable = [OCMockObject mockForClass:[NSTableView class]];
  id mockStagedTable = [OCMockObject mockForClass:[NSTableView class]];
  XTUnstagedDataSource *ustgds = [[XTUnstagedDataSource alloc] init];
  XTStagedDataSource *stgds = [[XTStagedDataSource alloc] init];

  [ustgds setRepo:repository];
  [stgds setRepo:repository];
  [self waitForRepoQueue];

  STAssertEquals([ustgds numberOfRowsInTableView:mockUnstagedTable], 2L, @"");
  STAssertEquals([stgds numberOfRowsInTableView:mockStagedTable], 0L, @"");

  XTStageViewController *controller = [[XTStageViewController alloc] init];
  const NSInteger clickedRow = 0;

  [controller setRepo:repository];
  controller.unstageDS = ustgds;
  controller.stageDS = stgds;
  controller.unstageTable = mockUnstagedTable;

  // Double-click in unstaged list
  [[[mockUnstagedTable stub]
      andReturnValue:OCMOCK_VALUE(clickedRow)] clickedRow];
  [[mockStagedTable stub] reloadData];
  [[mockUnstagedTable stub] reloadData];
  [controller unstagedDoubleClicked:mockUnstagedTable];
  [self waitForRepoQueue];

  STAssertEquals([ustgds numberOfRowsInTableView:mockUnstagedTable], 1L, @"");
  STAssertEquals([stgds numberOfRowsInTableView:mockStagedTable], 1L, @"");

  id mockColumn = [OCMockObject mockForClass:[NSTableColumn class]];

  [[[mockColumn expect] andReturn:@"name"] identifier];
  [[[mockColumn expect] andReturn:@"name"] identifier];

  // Two spaces are insterted before the name for aesthetics.
  STAssertEqualObjects([ustgds tableView:mockUnstagedTable
                           objectValueForTableColumn:mockColumn
                                                 row:0],
                       @"  fileB.txt", @"");
  STAssertEqualObjects([stgds tableView:mockUnstagedTable
                           objectValueForTableColumn:mockColumn
                                                 row:0],
                       @"  fileA.txt", @"");

  // Double-click in staged list

  [[[mockStagedTable stub] andReturnValue:OCMOCK_VALUE(clickedRow)] clickedRow];
  [[mockStagedTable stub] reloadData];
  [controller stagedDoubleClicked:mockStagedTable];
  [self waitForRepoQueue];

  STAssertEquals([ustgds numberOfRowsInTableView:mockUnstagedTable], 2L, @"");
  STAssertEquals([stgds numberOfRowsInTableView:mockUnstagedTable], 0L, @"");

  [mockUnstagedTable verify];
  [mockStagedTable verify];
}

- (void)testStageUnstageWithContent
{
  [super addInitialRepoContent];
  [self doStageUnstage];
}

- (void)testStageUnstageWithoutContent
{
  [self doStageUnstage];
}

- (void)testXTPartialStage
{
  [super addInitialRepoContent];

  NSString *mv = [NSString stringWithFormat:@"%@/file_to_move.txt", repoPath];
  NSMutableArray *lines = [NSMutableArray arrayWithCapacity:30];

  for (int n = 0; n < 30; n++) {
    [lines addObject:[NSString stringWithFormat:@"line number %d", n]];
  }
  [[lines componentsJoinedByString:@"\n"] writeToFile:mv
                                           atomically:YES
                                             encoding:NSASCIIStringEncoding
                                                error:nil];

  [repository stageAllFiles];
  [repository commitWithMessage:@"commit"
                          amend:NO
                    outputBlock:NULL
                          error:NULL];

  lines[5] = @"new line number 5.......";
  lines[15] = @"new line number 15.......";
  lines[25] = @"new line number 25.......";

  [[lines componentsJoinedByString:@"\n"] writeToFile:mv
                                           atomically:YES
                                             encoding:NSASCIIStringEncoding
                                                error:nil];

  XTUnstagedDataSource *ustgds = [[XTUnstagedDataSource alloc] init];
  [ustgds setRepo:repository];
  [self waitForRepoQueue];

  NSUInteger nc = [ustgds numberOfRowsInTableView:nil];
  STAssertTrue((nc == 1), @"found %d commits", nc);

  XTStagedDataSource *stgds = [[XTStagedDataSource alloc] init];
  [stgds setRepo:repository];
  [self waitForRepoQueue];

  nc = [stgds numberOfRowsInTableView:nil];
  STAssertTrue((nc == 0), @"found %d commits", nc);

  XTStageViewController *svc = [[XTStageViewController alloc] init];
  [svc setRepo:repository];
  [svc showUnstageFile:(ustgds.items)[0]];  // click on unstage table
  [svc stageChunk:2];                       // click on stage button

  [ustgds reload];
  [self waitForRepoQueue];

  nc = [ustgds numberOfRowsInTableView:nil];
  STAssertTrue((nc == 1), @"found %d commits", nc);

  [stgds reload];
  [self waitForRepoQueue];

  nc = [stgds numberOfRowsInTableView:nil];
  STAssertTrue((nc == 1), @"found %d commits", nc);

  [svc showStageFile:(stgds.items)[0]];  // click on stage table
  [svc unstageChunk:0];                  // click on unstage button

  [stgds reload];
  [self waitForRepoQueue];

  nc = [stgds numberOfRowsInTableView:nil];
  STAssertTrue((nc == 0), @"found %d commits", nc);
}

- (void)testXTDataSources
{
  [super addInitialRepoContent];

  NSString *mod = [NSString stringWithFormat:@"%@/file_to_mod.txt", repoPath];
  NSString *mv = [NSString stringWithFormat:@"%@/file_to_move.txt", repoPath];
  NSString *mvd = [NSString stringWithFormat:@"%@/file_moved.txt", repoPath];
  NSString *rm = [NSString stringWithFormat:@"%@/file_to_rm.txt", repoPath];
  NSString *new = [NSString stringWithFormat : @"%@/new_file.txt", repoPath];

  NSString *txt = @"some text";

  [txt writeToFile:mod atomically:YES encoding:NSASCIIStringEncoding error:nil];
  [txt writeToFile:mv atomically:YES encoding:NSASCIIStringEncoding error:nil];
  [txt writeToFile:rm atomically:YES encoding:NSASCIIStringEncoding error:nil];

  [repository stageAllFiles];
  [repository commitWithMessage:@"commit"
                          amend:NO
                    outputBlock:NULL
                          error:NULL];

  txt = @"more text";
  [txt writeToFile:mod atomically:YES encoding:NSASCIIStringEncoding error:nil];
  [[NSFileManager defaultManager] moveItemAtPath:mv toPath:mvd error:nil];
  [[NSFileManager defaultManager] removeItemAtPath:rm error:nil];
  [txt writeToFile:new atomically:YES encoding:NSASCIIStringEncoding error:nil];

  XTUnstagedDataSource *ustgds = [[XTUnstagedDataSource alloc] init];
  [ustgds setRepo:repository];
  [self waitForRepoQueue];

  NSUInteger nc = [ustgds numberOfRowsInTableView:nil];
  STAssertTrue((nc == 5), @"found %d commits", nc);

  NSDictionary *expected =
      @{@"file_to_mod.txt" : @"M", @"file_to_move.txt" : @"D",
        @"file_moved.txt" : @"?", @"file_to_rm.txt" : @"D",
        @"new_file.txt" : @"?"};

  NSArray *items = [ustgds items];
  [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    XTFileIndexInfo *info = obj;
    NSString *status = expected[info.name];
    STAssertEqualObjects(info.status, status, @"incorrect state file(%lu):%@",
                         idx, info.name);
  }];

  [repository stageAllFiles];

  XTStagedDataSource *stgds = [[XTStagedDataSource alloc] init];
  [stgds setRepo:repository];
  [self waitForRepoQueue];

  STAssertEquals([stgds numberOfRowsInTableView:nil], 5L, @"");

  expected = @{@"file_to_mod.txt" : @"M", @"file_to_move.txt" : @"D",
               @"file_moved.txt" : @"A", @"file_to_rm.txt" : @"D",
               @"new_file.txt" : @"A"};

  items = [stgds items];
  [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
    XTFileIndexInfo *info = obj;
    NSString *status = expected[info.name];
    STAssertEqualObjects(info.status, status, @"incorrect state file(%lu):%@",
                         idx, info.name);
  }];
}

- (void)testCommit
{
  [super addInitialRepoContent];

  NSString *oldHeadSHA = [repository headSHA];
  XTStageViewController *controller = [[XTStageViewController alloc] init];
  NSString *testMessage = @"controller test message";
  NSString *newFileName = @"commitfile.txt";
  NSString *newFilePath =
      [NSString stringWithFormat:@"%@/%@", repoPath, newFileName];
  NSError *error = nil;

  [@"new file" writeToFile:newFilePath
                atomically:YES
                  encoding:NSUTF8StringEncoding
                     error:&error];
  STAssertNil(error, @"");
  [repository stageFile:newFilePath];
  controller.message = testMessage;
  [controller setRepo:repository];
  [controller commit:nil];
  [self waitForRepoQueue];

  NSString *newHeadSHA = [repository headSHA];
  NSDictionary *header = nil;
  NSString *message = nil;
  NSArray *files = nil;

  STAssertFalse([oldHeadSHA isEqual:newHeadSHA], @"");
  STAssertTrue([repository parseCommit:newHeadSHA
                            intoHeader:&header
                               message:&message
                                 files:&files],
               @"");

  STAssertNotNil(header, @"");
  STAssertNotNil(message, @"");
  STAssertNotNil(files, @"");

  // Somewhere in there, git appended a \n to the message.
  message = [message stringByTrimmingCharactersInSet:
          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
  STAssertEqualObjects(message, testMessage, @"");
  STAssertEqualObjects(files, @[ newFileName ], @"");

  NSArray *parents = header[XTParentSHAsKey];

  STAssertEquals([parents count], 1UL, @"");
  STAssertEqualObjects(parents[0], oldHeadSHA, @"");
}

- (void)testNewFileDiff
{
  NSString *newFileName = @"newfile.txt";
  NSString *newFilePath =
      [NSString stringWithFormat:@"%@/%@", repoPath, newFileName];
  NSError *error = nil;

  [@"line 1\nline 2\n\nline 4" writeToFile:newFilePath
                                atomically:YES
                                  encoding:NSUTF8StringEncoding
                                     error:&error];
  STAssertNil(error, @"");

  XTStageViewController *svc = [[XTStageViewController alloc] init];
  [svc setRepo:repository];

  NSString *diff = [svc diffForNewFile:newFileName];
  STAssertEqualObjects(diff,
                       @"diff --git /dev/null b/newfile.txt\n"
                        "--- /dev/null\n"
                        "+++ b/newfile.txt\n"
                        "@@ -0,0 +1,4 @@\n"
                        "+line 1\n"
                        "+line 2\n"
                        "+\n"
                        "+line 4\n",
                       @"");

  NSString *html = [XTHTML parseDiff:diff];
  STAssertNotNil(html, @"");
}

@end
