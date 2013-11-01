#import <Cocoa/Cocoa.h>

@class XTRepository;

@class XTCommitViewController;
@class XTFileListDataSource;
@class XTFileViewController;
@class XTHistoryDataSource;
@class XTSideBarDataSource;
@class XTSideBarOutlineView;

@interface XTHistoryViewController : NSViewController
{
  IBOutlet XTSideBarDataSource *_sideBarDS;
  IBOutlet XTHistoryDataSource *_historyDS;
  IBOutlet XTCommitViewController *_commitViewController;
  IBOutlet NSTableView *_historyTable;
  IBOutlet XTSideBarOutlineView *_sidebarOutline;
  IBOutlet NSView *_commitView;
  IBOutlet NSSplitView *_sidebarSplitView;
  IBOutlet NSSplitView *_mainSplitView;
  IBOutlet NSTabView *_commitTabView;
  IBOutlet NSMenu *_branchContextMenu;
  IBOutlet NSMenu *_remoteContextMenu;
  IBOutlet NSMenu *_tagContextMenu;
  IBOutlet NSMenu *_stashContextMenu;
 @private
  XTRepository *_repo;
  XTFileViewController *_fileViewController;
  NSUInteger _savedSidebarWidth;
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
- (IBAction)copyRemoteURL:(id)sender;
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

@property(readonly) XTSideBarDataSource *sideBarDS;
@property(readonly) XTHistoryDataSource *historyDS;
@property(readonly) NSTableView *historyTable;
@property(readonly) NSMenu *branchContextMenu;
@property(readonly) NSMenu *remoteContextMenu;
@property(readonly) NSMenu *tagContextMenu;
@property(readonly) NSMenu *stashContextMenu;

// For testing
- (id)initWithRepository:(XTRepository *)repository
                 sidebar:(XTSideBarOutlineView *)sidebar;

@end
