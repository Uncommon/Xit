//
//  XTHistoryView.h
//  Xit
//
//  Created by German Laullon on 05/08/11.
//

#import <Cocoa/Cocoa.h>

@class XTRepository;

@class XTSideBarDataSource;
@class XTSideBarOutlineView;
@class XTHistoryDataSource;
@class XTCommitViewController;

@interface XTHistoryViewController : NSViewController
{
    IBOutlet XTSideBarDataSource *sideBarDS;
    IBOutlet XTHistoryDataSource *historyDS;
    IBOutlet XTCommitViewController *commitViewController;
    IBOutlet NSTableView *historyTable;
    IBOutlet XTSideBarOutlineView *sidebarOutline;
    IBOutlet NSView *commitView;
    IBOutlet NSSplitView *sidebarSplitView;
    IBOutlet NSSplitView *mainSplitView;
    @private
    XTRepository *repo;
    NSUInteger savedSidebarWidth;
}

- (void)setRepo:(XTRepository *)newRepo;

- (IBAction)checkOutBranch:(id)sender;
- (IBAction)renameBranch:(id)sender;
- (IBAction)mergeBranch:(id)sender;
- (IBAction)deleteBranch:(id)sender;
- (IBAction)renameTag:(id)sender;
- (IBAction)deleteTag:(id)sender;
- (IBAction)renameRemote:(id)sender;
- (IBAction)deleteRemote:(id)sender;
- (IBAction)popStash:(id)sender;
- (IBAction)applyStash:(id)sender;
- (IBAction)dropStash:(id)sender;

- (IBAction)toggleLayout:(id)sender;
- (IBAction)toggleSideBar:(id)sender;

- (IBAction)sideBarItemRenamed:(id)sender;

- (NSString *)selectedBranch;
- (void)selectBranch:(NSString *)branch;

@property (readonly) XTSideBarDataSource *sideBarDS;
@property (readonly) XTHistoryDataSource *historyDS;

// For testing
- (id)initWithRepository:(XTRepository *)repository sidebar:(XTSideBarOutlineView *)sidebar;

@end
