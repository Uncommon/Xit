//
//  XTHistoryView.m
//  Xit
//
//  Created by German Laullon on 05/08/11.
//

#import "XTHistoryViewController.h"
#import "XTCommitViewController.h"
#import "XTLocalBranchItem.h"
#import "XTRepository.h"
#import "XTSideBarDataSource.h"
#import "XTStatusView.h"

@implementation XTHistoryViewController

@synthesize sideBarDS;
@synthesize historyDS;

- (void)awakeFromNib {
    // Remove intercell spacing so the history lines will connect
    NSSize cellSpacing = [historyTable intercellSpacing];
    cellSpacing.height = 0;
    [historyTable setIntercellSpacing:cellSpacing];

    // Without this, the first group title moves when you hide its contents
    [sidebarOutline setFloatsGroupRows:NO];
}

- (NSString *)nibName {
    NSLog(@"nibName: %@ (%@)", [super nibName], [self class]);
    return NSStringFromClass([self class]);
}

- (void)setRepo:(XTRepository *)newRepo {
    repo = newRepo;
    [sideBarDS setRepo:newRepo];
    [historyDS setRepo:newRepo];
    [commitViewController setRepo:newRepo];
    [[commitViewController view] setFrame:NSMakeRect(0, 0, [commitView frame].size.width, [commitView frame].size.height)];
    [commitView addSubview:[commitViewController view]];
}

- (IBAction)checkOutBranch:(id)sender {
    dispatch_async(repo.queue, ^{
        NSError *error = nil;
        NSArray *args = [NSArray arrayWithObjects:@"checkout", [self selectedBranch], nil];

        [repo executeGitWithArgs:args error:&error];
        if (error != nil)
            [XTStatusView updateStatus:@"Checkout failed" command:[args componentsJoinedByString:@" "] output:[[error userInfo] valueForKey:@"output"] forRepository:repo];
    });
}

- (IBAction)toggleLayout:(id)sender {
    // TODO: improve it
    NSLog(@"toggleLayout, %lu,%d", ((NSButton *)sender).state, (((NSButton *)sender).state == 1));
    [mainSplitView setVertical:(((NSButton *)sender).state == 1)];
    [mainSplitView adjustSubviews];
}

- (IBAction)toggleSideBar:(id)sender {
    // TODO: improve it
    const CGFloat newWidth = ([sender state] == NSOnState) ? 180 : 0;
    [sidebarSplitView setPosition:newWidth ofDividerAtIndex:0 ];
}

- (NSString *)selectedBranch {
    id selection = [sidebarOutline itemAtRow:[sidebarOutline selectedRow]];

    if (selection == nil)
        return nil;
    if ([selection isKindOfClass:[XTLocalBranchItem class]])
        return [(XTLocalBranchItem *) selection title];
    return nil;
}

- (void)selectBranch:(NSString *)branch {
    XTLocalBranchItem *branchItem = [sideBarDS itemForBranchName:branch];

    if (branchItem != nil) {
        [sidebarOutline expandItem:[sidebarOutline itemAtRow:XT_BRANCHES]];

        const NSInteger row = [sidebarOutline rowForItem:branchItem];

        if (row != -1)
            [sidebarOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }
}

- (id)initWithRepository:(XTRepository *)repository sidebar:(NSOutlineView *)sidebar {
    if ([self init] == nil)
        return nil;

    self->repo = repository;
    self->sidebarOutline = sidebar;
    self->sideBarDS = [[XTSideBarDataSource alloc] init];
    return self;
}

@end
