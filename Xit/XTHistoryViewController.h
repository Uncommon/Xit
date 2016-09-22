#import <Cocoa/Cocoa.h>

@class XTRepository;

@class XTFileViewController;
@class XTHistoryTableController;
@class XTSideBarDataSource;
@class XTSideBarOutlineView;

/**
  View controller for history view, with the history list on top and detail
  views below.
 */
@interface XTHistoryViewController : NSViewController<NSSplitViewDelegate>
{
  IBOutlet XTSideBarDataSource *_sideBarDS;
  IBOutlet NSTableView *_historyTable;
  IBOutlet XTSideBarOutlineView *_sidebarOutline;
  IBOutlet NSMenu *_branchContextMenu;
  IBOutlet NSMenu *_remoteContextMenu;
  IBOutlet NSMenu *_tagContextMenu;
  IBOutlet NSMenu *_stashContextMenu;
 @private
  __weak XTRepository *_repo;
  XTFileViewController *_fileViewController;
  NSUInteger _savedSidebarWidth, _savedHistorySize;
}

- (void)windowDidLoad;
- (void)setRepo:(XTRepository *)newRepo;
- (void)reload;

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

- (BOOL)sideBarHidden;
- (BOOL)historyHidden;
- (BOOL)detailsHidden;
- (IBAction)toggleSideBar:(id)sender;
- (IBAction)toggleHistory:(id)sender;
- (IBAction)toggleDetails:(id)sender;

- (IBAction)sideBarItemRenamed:(id)sender;

- (void)selectBranch:(NSString *)branch;

@property(readonly) NSString *selectedBranch;
@property(readonly) XTSideBarDataSource *sideBarDS;
@property(readonly) NSTableView *historyTable;
@property(readonly) NSMenu *branchContextMenu;
@property(readonly) NSMenu *remoteContextMenu;
@property(readonly) NSMenu *tagContextMenu;
@property(readonly) NSMenu *stashContextMenu;

@property (weak) IBOutlet NSSplitView *sidebarSplitView;
@property (weak) IBOutlet NSSplitView *mainSplitView;
@property (weak) IBOutlet XTHistoryTableController *tableController;
@property (weak) IBOutlet NSTableView *commitTable;

// For testing
- (instancetype)initWithRepository:(XTRepository *)repository
                 sidebar:(XTSideBarOutlineView *)sidebar;

@end
