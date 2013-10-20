#import <Cocoa/Cocoa.h>

#import "XTTest.h"
#import "XTDocument.h"
#import "XTHistoryViewController.h"
#import "XTLocalBranchItem.h"
#import "XTRepository.h"
#import "XTSideBarDataSource.h"
#import "XTSideBarOutlineView.h"
#import "XTStatusView.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import <OCMock/OCMock.h>

#import <Cocoa/Cocoa.h>
@interface XTHistoryViewControllerTest : XTTest

@property NSDictionary *statusData;

@end

#import <Cocoa/Cocoa.h>
@interface XTHistoryViewControllerTestNoRepo : SenTestCase

@end

@implementation XTHistoryViewControllerTest

@synthesize statusData;

- (void)setUp
{
  [super setUp];
  self.statusData = nil;
  // Don't let change notifications cause unexpected calls.
  [repository stop];
}

- (void)tearDown
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super tearDown];
}

- (void)testCheckoutBranch
{
  [repository start];
  if (![repository createBranch:@"b1"]) {
    STFail(@"Create Branch 'b1'");
  }

  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:repository
                                                  sidebar:mockSidebar];

  [controller.sideBarDS setRepo:repository];
  [[mockSidebar stub] reloadData];
  [[mockSidebar expect] setDelegate:controller.sideBarDS];
  [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData)
                                         withObject:nil
                                      waitUntilDone:NO];
  [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData)
                                         withObject:nil
                                      waitUntilDone:NO];
  [[mockSidebar expect] expandItem:nil expandChildren:YES];
  [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData)
                                         withObject:nil
                                      waitUntilDone:NO];
  [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData)
                                         withObject:nil
                                      waitUntilDone:NO];
  [[mockSidebar expect] expandItem:nil expandChildren:YES];

  [controller.sideBarDS reload];
  [self waitForRepoQueue];

  // selectBranch
  NSInteger row = 2, noRow = -1;

  [[[mockSidebar expect] andReturn:nil] itemAtRow:XTBranchesGroupIndex];
  [[mockSidebar expect] expandItem:OCMOCK_ANY];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)]
      rowForItem:OCMOCK_ANY];
  [[mockSidebar expect] selectRowIndexes:OCMOCK_ANY byExtendingSelection:NO];

  // selectedBranch
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];
  [[[mockSidebar expect] andReturn:
          [controller.sideBarDS itemNamed:@"master"
                                  inGroup:XTBranchesGroupIndex]] itemAtRow:row];

  // selectedBranch from checkOutBranch
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(noRow)] contextMenuRow];
  [[[mockSidebar expect] andReturn:
          [controller.sideBarDS itemNamed:@"master"
                                  inGroup:XTBranchesGroupIndex]] itemAtRow:row];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];

  [controller.sideBarDS outlineView:mockSidebar
             numberOfChildrenOfItem:nil];  // initialize sidebarDS->outline
  [self waitForRepoQueue];
  STAssertEqualObjects([repository currentBranch], @"b1", @"");
  [controller selectBranch:@"master"];
  STAssertEqualObjects([controller selectedBranch], @"master", @"");
  [controller checkOutBranch:nil];
  [self waitForRepoQueue];
  STAssertEqualObjects([repository currentBranch], @"master", @"");
}

- (void)makeTwoStashes
{
  STAssertTrue([self writeTextToFile1:@"second text"], @"");
  STAssertTrue([repository saveStash:@"s1"], @"");
  STAssertTrue([self writeTextToFile1:@"third text"], @"");
  STAssertTrue([repository saveStash:@"s2"], @"");
}

- (void)assertStashes:(NSArray *)expectedStashes
{
  NSMutableArray *composedStashes = [NSMutableArray array];
  int i = 0;

  for (NSString *name in expectedStashes)
    [composedStashes addObject:
        [NSString stringWithFormat:@"stash@{%d} On master: %@", i++, name]];

  NSMutableArray *stashes = [NSMutableArray array];

  [repository readStashesWithBlock:^(NSString *commit, NSString *name) {
    [stashes addObject:name];
  }];
  STAssertEqualObjects(stashes, composedStashes, @"");
}

- (void)doStashAction:(SEL)action
            stashName:(NSString *)stashName
      expectedRemains:(NSArray *)expectedRemains
         expectedText:(NSString *)expectedText
{
  [self makeTwoStashes];
  [self assertStashes:@[ @"s2", @"s1" ]];

  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:repository
                                                  sidebar:mockSidebar];
  NSInteger stashRow = 2, noRow = -1;

  [controller.sideBarDS setRepo:repository];
  [controller.sideBarDS reload];
  [self waitForRepoQueue];

  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(noRow)] contextMenuRow];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(stashRow)] selectedRow];
  [[[mockSidebar expect] andReturn:[controller.sideBarDS
      itemNamed:stashName
        inGroup:XTStashesGroupIndex]] itemAtRow:stashRow];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  [controller performSelector:action withObject:nil];
#pragma clang diagnostic pop
  [self waitForRepoQueue];
  [self assertStashes:expectedRemains];

  NSError *error = nil;
  NSString *text = [NSString stringWithContentsOfFile:file1Path
                                             encoding:NSASCIIStringEncoding
                                                error:&error];

  STAssertNil(error, @"");
  STAssertEqualObjects(text, expectedText, @"");
}

- (void)testPopStash1
{
  [self doStashAction:@selector(popStash:)
            stashName:@"stash@{1} On master: s1"
      expectedRemains:@[ @"s2" ]
         expectedText:@"second text"];
}

- (void)testPopStash2
{
  [self doStashAction:@selector(popStash:)
            stashName:@"stash@{0} On master: s2"
      expectedRemains:@[ @"s1" ]
         expectedText:@"third text"];
}

- (void)testApplyStash1
{
  [self doStashAction:@selector(applyStash:)
            stashName:@"stash@{1} On master: s1"
      expectedRemains:@[ @"s2", @"s1" ]
         expectedText:@"second text"];
}

- (void)testApplyStash2
{
  [self doStashAction:@selector(applyStash:)
            stashName:@"stash@{0} On master: s2"
      expectedRemains:@[ @"s2", @"s1" ]
         expectedText:@"third text"];
}

- (void)testDropStash1
{
  [self doStashAction:@selector(dropStash:)
            stashName:@"stash@{1} On master: s1"
      expectedRemains:@[ @"s2" ]
         expectedText:@"some text"];
}

- (void)testDropStash2
{
  [self doStashAction:@selector(dropStash:)
            stashName:@"stash@{0} On master: s2"
      expectedRemains:@[ @"s1" ]
         expectedText:@"some text"];
}

- (void)testMergeText
{
  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:repository
                                                  sidebar:mockSidebar];
  XTLocalBranchItem *branchItem =
      [[XTLocalBranchItem alloc] initWithTitle:@"branch"];
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Merge"
                                                action:@selector(mergeBranch:)
                                         keyEquivalent:@""];
  NSInteger row = 1;

  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] contextMenuRow];
  [[[mockSidebar expect] andReturn:branchItem] itemAtRow:row];

  STAssertTrue([controller validateMenuItem:item], nil);
  STAssertEqualObjects([item title], @"Merge branch into master", nil);
}

- (void)testMergeDisabled
{
  // Merge should be disabled if the selected item is the current branch.
  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:repository
                                                  sidebar:mockSidebar];
  XTLocalBranchItem *branchItem =
      [[XTLocalBranchItem alloc] initWithTitle:@"master"];
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Merge"
                                                action:@selector(mergeBranch:)
                                         keyEquivalent:@""];
  NSInteger row = 1;

  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] contextMenuRow];
  [[[mockSidebar expect] andReturn:branchItem] itemAtRow:row];

  STAssertFalse([controller validateMenuItem:item], nil);
  STAssertEqualObjects([item title], @"Merge", nil);
}

- (void)statusUpdated:(NSNotification *)note
{
  self.statusData = [note userInfo];
}

- (void)testMergeSuccess
{
  NSString *file2Name = @"file2.txt";

  STAssertTrue([repository createBranch:@"task"], nil);
  STAssertTrue([self commitNewTextFile:file2Name content:@"branch text"], nil);

  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:repository
                                                  sidebar:mockSidebar];
  XTLocalBranchItem *masterItem =
      [[XTLocalBranchItem alloc] initWithTitle:@"master"];
  NSInteger row = 1;

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(statusUpdated:)
                                               name:XTStatusNotification
                                             object:repository];

  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];
  [[[mockSidebar expect] andReturn:masterItem] itemAtRow:row];
  [controller mergeBranch:nil];
  [self waitForQueue:dispatch_get_main_queue()];
  STAssertEqualObjects([self.statusData valueForKey:XTStatusTextKey],
                       @"Merged master into task", nil);

  NSString *file2Path = [repoPath stringByAppendingPathComponent:file2Name];

  STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:file1Path],
               nil);
  STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:file2Path],
               nil);
}

- (void)testMergeFailure
{
  STAssertTrue([repository createBranch:@"task"], nil);
  STAssertTrue([self writeTextToFile1:@"conflicting branch"], nil);
  STAssertTrue([repository stageFile:file1Path], nil);
  STAssertTrue([repository commitWithMessage:@"conflicting commit"
                                       amend:NO
                                 outputBlock:NULL
                                       error:NULL], nil);

  STAssertTrue([repository checkout:@"master" error:NULL], nil);
  STAssertTrue([self writeTextToFile1:@"conflicting master"], nil);
  STAssertTrue([repository stageFile:file1Path], nil);
  STAssertTrue([repository commitWithMessage:@"conflicting commit 2"
                                       amend:NO
                                 outputBlock:NULL
                                       error:NULL], nil);

  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:repository
                                                  sidebar:mockSidebar];
  XTLocalBranchItem *masterItem =
      [[XTLocalBranchItem alloc] initWithTitle:@"task"];
  NSInteger row = 1;

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(statusUpdated:)
                                               name:XTStatusNotification
                                             object:repository];

  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];
  [[[mockSidebar expect] andReturn:masterItem] itemAtRow:row];
  [controller mergeBranch:nil];
  [self waitForQueue:dispatch_get_main_queue()];
  STAssertEqualObjects([self.statusData valueForKey:XTStatusTextKey],
                       @"Merge failed", nil);
}

@end

@implementation XTHistoryViewControllerTestNoRepo

- (void)testDeleteCurrentBranch
{
  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  id mockRepo = [OCMockObject mockForClass:[XTRepository class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:mockRepo
                                                  sidebar:mockSidebar];
  NSMenuItem *menuItem =
      [[NSMenuItem alloc] initWithTitle:@"Delete"
                                 action:@selector(deleteBranch:)
                          keyEquivalent:@""];
  NSString *branchName = @"master";
  XTLocalBranchItem *branchItem =
      [[XTLocalBranchItem alloc] initWithTitle:branchName];
  NSInteger row = 1;
  BOOL isWriting = NO;

  [[[mockRepo expect] andReturnValue:OCMOCK_VALUE(isWriting)] isWriting];
  [[[mockRepo expect] andReturn:branchName] currentBranch];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] contextMenuRow];
  [[[mockSidebar expect] andReturn:branchItem] itemAtRow:row];
  STAssertFalse([controller validateMenuItem:menuItem], nil);
  [mockRepo verify];
  [mockSidebar verify];
}

- (void)testDeleteOtherBranch
{
  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  id mockRepo = [OCMockObject mockForClass:[XTRepository class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:mockRepo
                                                  sidebar:mockSidebar];
  NSMenuItem *menuItem =
      [[NSMenuItem alloc] initWithTitle:@"Delete"
                                 action:@selector(deleteBranch:)
                          keyEquivalent:@""];
  NSString *clickedBranchName = @"topic";
  NSString *currentBranchName = @"master";
  XTLocalBranchItem *branchItem =
      [[XTLocalBranchItem alloc] initWithTitle:clickedBranchName];
  NSInteger row = 1;
  BOOL isWriting = NO;

  [[[mockRepo expect] andReturnValue:OCMOCK_VALUE(isWriting)] isWriting];
  [[[mockRepo expect] andReturn:currentBranchName] currentBranch];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] contextMenuRow];
  [[[mockSidebar expect] andReturn:branchItem] itemAtRow:row];
  STAssertTrue([controller validateMenuItem:menuItem], nil);
  [mockRepo verify];
  [mockSidebar verify];
}

@end
