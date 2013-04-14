//
//  XTHistoryViewControllerTest.m
//  Xit
//
//  Created by David Catmull on 6/1/12.
//

#import <Cocoa/Cocoa.h>

#import "XTTest.h"
#import "XTDocument.h"
#import "XTHistoryViewController.h"
#import "XTLocalBranchItem.h"
#import "XTRepository.h"
#import "XTSideBarDataSource.h"
#import "XTSideBarOutlineView.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import <OCMock/OCMock.h>

@interface XTHistoryViewControllerTest : XTTest

@end

@implementation XTHistoryViewControllerTest

- (void)testCheckoutBranch {
    [repository start];
    if (![repository createBranch:@"b1"]) {
        STFail(@"Create Branch 'b1'");
    }

    id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
    XTHistoryViewController *controller = [[XTHistoryViewController alloc] initWithRepository:repository sidebar:mockSidebar];

    [controller.sideBarDS setRepo:repository];
    [[mockSidebar expect] setDelegate:controller.sideBarDS];
    [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    [[mockSidebar expect] expandItem:nil expandChildren:YES];
    [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    [[mockSidebar expect] expandItem:nil expandChildren:YES];

    [controller.sideBarDS reload];
    [repository waitForQueue];

    // selectBranch
    NSInteger row = 2, noRow = -1;

    [[[mockSidebar expect] andReturn:nil] itemAtRow:XTBranchesGroupIndex];
    [[mockSidebar expect] expandItem:OCMOCK_ANY];
    [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] rowForItem:OCMOCK_ANY];
    [[mockSidebar expect] selectRowIndexes:OCMOCK_ANY byExtendingSelection:NO];

    // selectedBranch
    [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];
    [[[mockSidebar expect] andReturn:[controller.sideBarDS itemNamed:@"master" inGroup:XTBranchesGroupIndex]] itemAtRow:row];

    // selectedBranch from checkOutBranch
    [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(noRow)] contextMenuRow];
    [[[mockSidebar expect] andReturn:[controller.sideBarDS itemNamed:@"master" inGroup:XTBranchesGroupIndex]] itemAtRow:row];
    [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];

    [controller.sideBarDS outlineView:mockSidebar numberOfChildrenOfItem:nil]; // initialize sidebarDS->outline
    [repository waitForQueue];
    STAssertEqualObjects([repository currentBranch], @"b1", @"");
    [controller selectBranch:@"master"];
    STAssertEqualObjects([controller selectedBranch], @"master", @"");
    [controller checkOutBranch:nil];
    [repository waitForQueue];
    STAssertEqualObjects([repository currentBranch], @"master", @"");
}

- (void)makeTwoStashes {
    STAssertTrue([self writeTextToFile1:@"second text"], @"");
    STAssertTrue([repository saveStash:@"s1"], @"");
    STAssertTrue([self writeTextToFile1:@"third text"], @"");
    STAssertTrue([repository saveStash:@"s2"], @"");
}

- (void)assertStashes:(NSArray *)expectedStashes {
    NSMutableArray *composedStashes = [NSMutableArray array];
    int i = 0;

    for (NSString *name in expectedStashes)
        [composedStashes addObject:[NSString stringWithFormat:@"stash@{%d} On master: %@", i++, name]];

    NSMutableArray *stashes = [NSMutableArray array];

    [repository readStashesWithBlock:^(NSString *commit, NSString *name) {
        [stashes addObject:name];
    }];
    STAssertEqualObjects(stashes, composedStashes, @"");
}

- (void)doStashAction:(SEL)action stashName:(NSString *)stashName expectedRemains:(NSArray *)expectedRemains expectedText:(NSString *)expectedText {
    [self makeTwoStashes];
    [self assertStashes:[NSArray arrayWithObjects:@"s2", @"s1", nil]];

    id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
    XTHistoryViewController *controller = [[XTHistoryViewController alloc] initWithRepository:repository sidebar:mockSidebar];
    NSInteger stashRow = 2, noRow = -1;

    [controller.sideBarDS setRepo:repository];
    [controller.sideBarDS reload];
    [repository waitForQueue];

    [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(noRow)] contextMenuRow];
    [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(stashRow)] selectedRow];
    [[[mockSidebar expect] andReturn:[controller.sideBarDS itemNamed:stashName inGroup:XTStashesGroupIndex]] itemAtRow:stashRow];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [controller performSelector:action withObject:nil];
#pragma clang diagnostic pop
    [repository waitForQueue];
    [self assertStashes:expectedRemains];

    NSError *error = nil;
    NSString *text =  [NSString stringWithContentsOfFile:file1Path encoding:NSASCIIStringEncoding error:&error];

    STAssertNil(error, @"");
    STAssertEqualObjects(text, expectedText, @"");
}

- (void)testPopStash1 {
    [self doStashAction:@selector(popStash:) stashName:@"stash@{1} On master: s1" expectedRemains:[NSArray arrayWithObjects:@"s2", nil] expectedText:@"second text"];
}

- (void)testPopStash2 {
    [self doStashAction:@selector(popStash:) stashName:@"stash@{0} On master: s2" expectedRemains:[NSArray arrayWithObjects:@"s1", nil] expectedText:@"third text"];
}

- (void)testApplyStash1 {
    [self doStashAction:@selector(applyStash:) stashName:@"stash@{1} On master: s1" expectedRemains:[NSArray arrayWithObjects:@"s2", @"s1", nil] expectedText:@"second text"];
}

- (void)testApplyStash2 {
    [self doStashAction:@selector(applyStash:) stashName:@"stash@{0} On master: s2" expectedRemains:[NSArray arrayWithObjects:@"s2", @"s1", nil] expectedText:@"third text"];
}

- (void)testDropStash1 {
    [self doStashAction:@selector(dropStash:) stashName:@"stash@{1} On master: s1" expectedRemains:[NSArray arrayWithObjects:@"s2", nil] expectedText:@"some text"];
}

- (void)testDropStash2 {
    [self doStashAction:@selector(dropStash:) stashName:@"stash@{0} On master: s2" expectedRemains:[NSArray arrayWithObjects:@"s1", nil] expectedText:@"some text"];
}

- (void)testMergeText {
    id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
    XTHistoryViewController *controller = [[XTHistoryViewController alloc] initWithRepository:repository sidebar:mockSidebar];
    XTLocalBranchItem *branchItem = [[XTLocalBranchItem alloc] initWithTitle:@"branch"];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Merge" action:@selector(mergeBranch:) keyEquivalent:@""];
    NSInteger row = 1;

    [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] contextMenuRow];
    [[[mockSidebar expect] andReturn:branchItem] itemAtRow:row];

    STAssertTrue([controller validateMenuItem:item], nil);
    STAssertEqualObjects([item title], @"Merge branch into master", nil);
}

- (void)testMergeDisabled {
    // Merge should be disabled if the selected item is the current branch.
    id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
    XTHistoryViewController *controller = [[XTHistoryViewController alloc] initWithRepository:repository sidebar:mockSidebar];
    XTLocalBranchItem *branchItem = [[XTLocalBranchItem alloc] initWithTitle:@"master"];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Merge" action:@selector(mergeBranch:) keyEquivalent:@""];
    NSInteger row = 1;

    [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] contextMenuRow];
    [[[mockSidebar expect] andReturn:branchItem] itemAtRow:row];

    STAssertFalse([controller validateMenuItem:item], nil);
    STAssertEqualObjects([item title], @"Merge", nil);
}

@end
