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
  NSUInteger _savedHistorySize;
}

- (void)windowDidLoad;
- (void)setRepo:(XTRepository *)newRepo;
- (void)reload;

- (BOOL)historyHidden;
- (BOOL)detailsHidden;
- (IBAction)toggleHistory:(id)sender;
- (IBAction)toggleDetails:(id)sender;

@property (readonly) XTFileViewController *fileViewController;
@property (readonly) NSTableView *historyTable;

@property (weak) IBOutlet NSSplitView *mainSplitView;
@property (weak) IBOutlet XTHistoryTableController *tableController;
@property (weak) IBOutlet NSTableView *commitTable;

// For testing
- (instancetype)initWithRepository:(XTRepository*)repository;

@end
