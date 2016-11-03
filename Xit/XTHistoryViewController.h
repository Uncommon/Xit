#import <Cocoa/Cocoa.h>

@class XTRepository;

@class XTFileViewController;
@class XTHistoryTableController;
@class XTSidebarController;
@class XTSideBarDataSource;
@class XTSideBarOutlineView;

/**
  View controller for history view, with the history list on top and detail
  views below.
 */
@interface XTHistoryViewController : NSViewController<NSSplitViewDelegate>
{
  IBOutlet NSTableView *_historyTable;
 @private
  __weak XTRepository *_repo;
  XTFileViewController *_fileViewController;
  NSUInteger _savedSidebarWidth, _savedHistorySize;
}

- (void)windowDidLoad;
- (void)setRepo:(XTRepository *)newRepo;
- (void)reload;

- (BOOL)sideBarHidden;
- (BOOL)historyHidden;
- (BOOL)detailsHidden;
- (IBAction)toggleSideBar:(id)sender;
- (IBAction)toggleHistory:(id)sender;
- (IBAction)toggleDetails:(id)sender;

@property(readonly) NSTableView *historyTable;

@property (strong) IBOutlet XTSidebarController *sidebarController;
@property (weak) IBOutlet NSSplitView *sidebarSplitView;
@property (weak) IBOutlet NSSplitView *mainSplitView;
@property (weak) IBOutlet XTHistoryTableController *tableController;
@property (weak) IBOutlet NSTableView *commitTable;

// For testing
- (instancetype)initWithRepository:(XTRepository*)repository
                           sidebar:(XTSideBarOutlineView*)sidebar;

@end
