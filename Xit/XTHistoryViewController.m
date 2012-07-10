//
//  XTHistoryView.m
//  Xit
//
//  Created by German Laullon on 05/08/11.
//

#import "XTHistoryViewController.h"
#import "XTCommitViewController.h"
#import "XTHistoryDataSource.h"
#import "XTHistoryItem.h"
#import "XTLocalBranchItem.h"
#import "XTRepository.h"
#import "XTSideBarDataSource.h"
#import "XTStatusView.h"
#import "PBGitRevisionCell.h"

@implementation XTHistoryViewController

@synthesize sideBarDS;
@synthesize historyDS;

- (id)initWithRepository:(XTRepository *)repository sidebar:(NSOutlineView *)sidebar {
    if ([self init] == nil)
        return nil;

    self->repo = repository;
    self->sidebarOutline = sidebar;
    self->sideBarDS = [[XTSideBarDataSource alloc] init];
    self->savedSidebarWidth = 180;
    return self;
}

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
    const CGFloat newWidth = ([sender state] == NSOnState) ? savedSidebarWidth : 0;
    if ([sender state] == NSOffState)
        savedSidebarWidth = [[[sidebarSplitView subviews] objectAtIndex:0] frame].size.width;
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

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)note {
    NSLog(@"%@", note);
    NSTableView *table = (NSTableView*)[note object];
    XTHistoryItem *item = [historyDS.items objectAtIndex:table.selectedRow];
    repo.selectedCommit = item.sha;
}

// These values came from measuring where the Finder switches styles
const NSUInteger
    kFullStyleThreshold = 280,
    kLongStyleThreshold = 210,
    kMediumStyleThreshold = 170,
    kShortStyleThreshold = 150;

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    if ([[aTableColumn identifier] isEqualToString:@"subject"]) {
        XTHistoryItem *item = [historyDS.items objectAtIndex:rowIndex];

        ((PBGitRevisionCell *)aCell).objectValue = item;
    } else if ([[aTableColumn identifier] isEqualToString:@"date"]) {
        const CGFloat width = [aTableColumn width];
        NSDateFormatterStyle dateStyle = NSDateFormatterShortStyle;
        NSDateFormatterStyle timeStyle = NSDateFormatterShortStyle;

        if (width > kFullStyleThreshold)
            dateStyle = NSDateFormatterFullStyle;
        else if (width > kLongStyleThreshold)
            dateStyle = NSDateFormatterLongStyle;
        else if (width > kMediumStyleThreshold)
            dateStyle = NSDateFormatterMediumStyle;
        else if (width > kShortStyleThreshold)
            dateStyle = NSDateFormatterShortStyle;
        else {
            dateStyle = NSDateFormatterShortStyle;
            timeStyle = NSDateFormatterNoStyle;
        }
        [[aCell formatter] setDateStyle:dateStyle];
        [[aCell formatter] setTimeStyle:timeStyle];
    }
}

@end
