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
