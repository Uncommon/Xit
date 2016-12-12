#import <Cocoa/Cocoa.h>

#import "XTTest.h"
#import "XTDocument.h"
#import "XTHistoryViewController.h"
#import "XTRepository.h"
#import "XTSideBarDataSource.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import <OCMock/OCMock.h>
#include "XTQueueUtils.h"
#import "Xit-Swift.h"

@interface XTSidebarControllerTest : XTTest
{
  XTSidebarController *controller;
  XTSideBarDataSource *sidebarDS;
  XTSideBarOutlineView *sidebar;
  id mockSidebar;
}

@end


@interface XTSidebarControllerTestNoRepo : XCTestCase

@end


@interface XTSideBarOutlineView ()

@property(readwrite) NSInteger contextMenuRow;

@end


@implementation XTSidebarControllerTest

- (void)setUp
{
  [super setUp];

  sidebar = [[XTSideBarOutlineView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
  [sidebar addTableColumn:[[NSTableColumn alloc] initWithIdentifier:@"column"]];
  sidebarDS = [[XTSideBarDataSource alloc] init];
  sidebar.dataSource = sidebarDS;
  controller = [[XTSidebarController alloc] init];
  controller.sidebarDS = sidebarDS;
  controller.repo = self.repository;
  controller.sidebarOutline = sidebar;
  [self waitForRepoQueue];
}

- (void)testCheckoutBranch
{
  XCTAssertTrue([self.repository createBranch:@"b1"]);

  [controller.sidebarDS setRepo:self.repository];
  [controller.sidebarDS reload];
  [self waitForRepoQueue];

  XCTAssertEqualObjects([self.repository currentBranch], @"b1", @"");
  [controller selectBranch:@"master"];
  XCTAssertEqualObjects([controller selectedBranch], @"master", @"");
  
  const NSInteger masterRow = 3;
  XTSideBarItem *masterItem = [sidebar itemAtRow:masterRow];
  
  sidebar.contextMenuRow = masterRow;
  XCTAssertEqualObjects(masterItem.title, @"master");
  [controller checkOutBranch:nil];
  [self waitForRepoQueue];
  XCTAssertEqualObjects([self.repository currentBranch], @"master", @"");
}

- (void)makeTwoStashes
{
  XCTAssertTrue([self writeTextToFile1:@"second text"], @"");
  XCTAssertTrue([self.repository saveStash:@"s1" includeUntracked:NO], @"");
  XCTAssertTrue([self writeTextToFile1:@"third text"], @"");
  XCTAssertTrue([self.repository saveStash:@"s2" includeUntracked:NO], @"");
}

- (void)assertStashes:(NSArray *)expectedStashes
{
  NSMutableArray *composedStashes = [NSMutableArray array];
  int i = 0;

  for (NSString *name in expectedStashes)
    [composedStashes addObject:
        [NSString stringWithFormat:@"stash@{%d} On master: %@", i++, name]];

  NSMutableArray *stashes = [NSMutableArray array];

  [self.repository readStashesWithBlock:^(NSString *commit, NSUInteger index, NSString *name) {
    [stashes addObject:name];
  }];
  XCTAssertEqualObjects(stashes, composedStashes, @"");
}

- (void)doStashAction:(void (^)())action
            stashName:(NSString *)stashName
      expectedRemains:(NSArray *)expectedRemains
         expectedText:(NSString *)expectedText
{
  [self makeTwoStashes];
  [self assertStashes:@[ @"s2", @"s1" ]];

  [controller.sidebarDS setRepo:self.repository];
  [controller.sidebarDS reload];
  [self waitForRepoQueue];
  [sidebar expandItem:nil expandChildren:YES];

  XTSideBarItem *stashItem =
      [controller.sidebarDS itemNamed:stashName inGroup:XTGroupIndexStashes];

  XCTAssertNotNil(stashItem);

  sidebar.contextMenuRow = [sidebar rowForItem:stashItem];
  action();
  [self waitForRepoQueue];
  [self assertStashes:expectedRemains];

  NSError *error = nil;
  NSString *text = [NSString stringWithContentsOfFile:self.file1Path
                                             encoding:NSASCIIStringEncoding
                                                error:&error];

  XCTAssertNil(error, @"");
  XCTAssertEqualObjects(text, expectedText, @"");
}

- (void)testPopStash1
{
  [self doStashAction:^{ [controller popStash:nil]; }
            stashName:@"On master: s1"
      expectedRemains:@[ @"s2" ]
         expectedText:@"second text"];
}

- (void)testPopStash2
{
  [self doStashAction:^{ [controller popStash:nil]; }
            stashName:@"On master: s2"
      expectedRemains:@[ @"s1" ]
         expectedText:@"third text"];
}

- (void)testApplyStash1
{
  [self doStashAction:^{ [controller applyStash:nil]; }
            stashName:@"On master: s1"
      expectedRemains:@[ @"s2", @"s1" ]
         expectedText:@"second text"];
}

- (void)testApplyStash2
{
  [self doStashAction:^{ [controller applyStash:nil]; }
            stashName:@"On master: s2"
      expectedRemains:@[ @"s2", @"s1" ]
         expectedText:@"third text"];
}

- (void)testDropStash1
{
  [self doStashAction:^{ [controller dropStash:nil]; }
            stashName:@"On master: s1"
      expectedRemains:@[ @"s2" ]
         expectedText:@"some text"];
}

- (void)testDropStash2
{
  [self doStashAction:^{ [controller dropStash:nil]; }
            stashName:@"On master: s2"
      expectedRemains:@[ @"s1" ]
         expectedText:@"some text"];
}

- (void)testMergeText
{
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Merge"
                                                action:@selector(mergeBranch:)
                                         keyEquivalent:@""];

  XCTAssertTrue([self.repository createBranch:@"branch"]);
  XCTAssertTrue([self.repository checkout:@"master" error:NULL]);
  [sidebarDS reload];
  [self waitForRepoQueue];
  [sidebar expandItem:nil expandChildren:YES];
  
  const NSInteger branchRow = 3;
  XTSideBarItem *branchItem = [sidebar itemAtRow:branchRow];
  
  XCTAssertEqualObjects(branchItem.title, @"branch");
  sidebar.contextMenuRow = branchRow;
  XCTAssertTrue([controller validateMenuItem:item]);
  XCTAssertEqualObjects([item title], @"Merge branch into master");
}

- (void)testMergeDisabled
{
  // Merge should be disabled if the selected item is the current branch.
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Merge"
                                                action:@selector(mergeBranch:)
                                         keyEquivalent:@""];

  XCTAssertFalse([controller validateMenuItem:item]);
  XCTAssertEqualObjects([item title], @"Merge");
}

- (void)testMergeSuccess
{
  NSString *file2Name = @"file2.txt";

  XCTAssertTrue([self.repository createBranch:@"task"]);
  XCTAssertTrue([self commitNewTextFile:file2Name content:@"branch text"]);

  [controller mergeBranch:nil];
  WaitForQueue(dispatch_get_main_queue());

  NSString *file2Path = [self.repoPath stringByAppendingPathComponent:file2Name];

  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.file1Path]);
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:file2Path]);
}

- (void)testMergeFailure
{
  NSError *error = nil;

  XCTAssertTrue([self.repository createBranch:@"task"]);
  XCTAssertTrue([self writeTextToFile1:@"conflicting branch"]);
  XCTAssertTrue([self.repository stageFile:self.file1Path error:&error]);
  XCTAssertTrue([self.repository commitWithMessage:@"conflicting commit"
                                             amend:NO
                                       outputBlock:NULL
                                             error:&error]);

  XCTAssertTrue([self.repository checkout:@"master" error:NULL]);
  XCTAssertTrue([self writeTextToFile1:@"conflicting master"]);
  XCTAssertTrue([self.repository stageFile:self.file1Path error:&error]);
  XCTAssertTrue([self.repository commitWithMessage:@"conflicting commit 2"
                                             amend:NO
                                       outputBlock:NULL
                                             error:&error]);

  [controller mergeBranch:nil];
  WaitForQueue(dispatch_get_main_queue());
}

@end
