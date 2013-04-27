#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@class XTRepository;

@class XTCommitViewController;
@class XTFileListDataSource;
@class XTHistoryDataSource;
@class XTSideBarDataSource;
@class XTSideBarOutlineView;

@interface XTHistoryViewController : NSViewController
{
    IBOutlet XTSideBarDataSource *sideBarDS;
    IBOutlet XTHistoryDataSource *historyDS;
    IBOutlet XTFileListDataSource *fileListDS;
    IBOutlet XTCommitViewController *commitViewController;
    IBOutlet NSTableView *historyTable;
    IBOutlet XTSideBarOutlineView *sidebarOutline;
    IBOutlet NSView *commitView;
    IBOutlet NSSplitView *sidebarSplitView;
    IBOutlet NSSplitView *mainSplitView;
    IBOutlet NSTabView *commitTabView;
    IBOutlet NSOutlineView *fileListOutline;
    IBOutlet QLPreviewView *filePreview;
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
- (IBAction)showDiffView:(id)sender;
- (IBAction)showTreeView:(id)sender;

- (IBAction)sideBarItemRenamed:(id)sender;

- (NSString *)selectedBranch;
- (void)selectBranch:(NSString *)branch;

@property (readonly) XTSideBarDataSource *sideBarDS;
@property (readonly) XTHistoryDataSource *historyDS;

// For testing
- (id)initWithRepository:(XTRepository *)repository sidebar:(XTSideBarOutlineView *)sidebar;

@end
