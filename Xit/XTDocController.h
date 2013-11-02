#import <Cocoa/Cocoa.h>

@class XTDocument;
@class XTHistoryViewController;
@class XTStageViewController;
@class XTRepository;
@class XTStatusView;

@interface XTDocController : NSWindowController {
  IBOutlet XTHistoryViewController *_historyView;
  IBOutlet XTStageViewController *_stageView;
  IBOutlet NSTabView *_tabs;
  IBOutlet NSProgressIndicator *_activity;
  XTDocument *_xtDocument;
}

- (id)initWithDocument:(XTDocument *)doc;

- (IBAction)refresh:(id)sender;
- (IBAction)newTag:(id)sender;
- (IBAction)newBranch:(id)sender;
- (IBAction)addRemote:(id)sender;

@end
