//
//  XTHistoryViewControllerTest.m
//  Xit
//
//  Created by David Catmull on 6/1/12.
//

#import <Cocoa/Cocoa.h>

#import "XTHistoryViewControllerTest.h"
#import "XTDocument.h"
#import "XTHistoryViewController.h"
#import "XTRepository.h"
#import "XTSideBarDataSource.h"
#import "GITBasic+XTRepository.h"
#import <OCMock/OCMock.h>

@implementation XTHistoryViewControllerTest

- (void)testCheckoutBranch {
    [repository start];
    if (![repository createBranch:@"b1"]) {
        STFail(@"Create Branch 'b1'");
    }

    id mockSidebar = [OCMockObject mockForClass:[NSOutlineView class]];
    XTHistoryViewController *historyView = [[XTHistoryViewController alloc] initWithRepository:repository sidebar:mockSidebar];

    [historyView.sideBarDS setRepo:repository];
    [[mockSidebar expect] setDelegate:historyView.sideBarDS];
    [[mockSidebar expect] reloadData];
    [[mockSidebar expect] reloadData];
    [[mockSidebar expect] reloadData];
    [[mockSidebar expect] reloadData];

    [historyView.sideBarDS reload];
    [repository waitUntilReloadEnd];

    // selectBranch
    NSInteger row = 2;

    [[[mockSidebar expect] andReturn:nil] itemAtRow:XT_BRANCHES];
    [[mockSidebar expect] expandItem:OCMOCK_ANY];
    [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] rowForItem:OCMOCK_ANY];
    [[mockSidebar expect] selectRowIndexes:OCMOCK_ANY byExtendingSelection:NO];

    // selectedBranch
    [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];
    [[[mockSidebar expect] andReturn:[historyView.sideBarDS itemForBranchName:@"master"]] itemAtRow:row];

    // selectedBranch from checkOutBranch
    [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];
    [[[mockSidebar expect] andReturn:[historyView.sideBarDS itemForBranchName:@"master"]] itemAtRow:row];

    [historyView.sideBarDS outlineView:mockSidebar numberOfChildrenOfItem:nil]; // initialize sidebarDS->outline
    [repository waitUntilReloadEnd];
    STAssertEqualObjects([repository currentBranch], @"b1", @"");
    [historyView selectBranch:@"master"];
    STAssertEqualObjects([historyView selectedBranch], @"master", @"");
    [historyView checkOutBranch:nil];
    [repository waitUntilReloadEnd];
    STAssertEqualObjects([repository currentBranch], @"master", @"");
}

@end
