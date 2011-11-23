//
//  XTHistoryView.h
//  Xit
//
//  Created by German Laullon on 05/08/11.
//

#import <Cocoa/Cocoa.h>

@class XTRepository;

@class XTSideBarDataSource;
@class XTHistoryDataSource;
@class XTCommitViewController;

@interface XTHistoryViewController : NSViewController
{
    IBOutlet XTSideBarDataSource *sideBarDS;
    IBOutlet XTHistoryDataSource *historyDS;
    IBOutlet XTCommitViewController *commitViewController;
    IBOutlet NSTableView *historyTable;
    IBOutlet NSOutlineView *sidebarOutline;
    IBOutlet NSView *commitView;
    IBOutlet NSSplitView *sidebarSplitView;
    IBOutlet NSSplitView *mainSplitView;
    @private
    XTRepository *repo;
}

- (void)setRepo:(XTRepository *)newRepo;

- (IBAction)toggleLayout:(id)sender;
- (IBAction)toggleSideBar:(id)sender;

@end
