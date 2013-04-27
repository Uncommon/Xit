#import <Cocoa/Cocoa.h>

@class XTDocument;
@class XTHistoryViewController;
@class XTStageViewController;
@class XTFileViewController;
@class XTRepository;
@class XTStatusView;

@interface XTDocController : NSWindowController {
    IBOutlet XTHistoryViewController *historyView;
    IBOutlet XTStageViewController *stageView;
    IBOutlet XTFileViewController *fileListView;
    IBOutlet NSTabView *tabs;
    IBOutlet NSProgressIndicator *activity;
    IBOutlet XTStatusView *statusView;
    XTDocument *document;
}

- (id)initWithDocument:(XTDocument *)doc;

- (IBAction)refresh:(id)sender;
- (IBAction)newTag:(id)sender;
- (IBAction)newBranch:(id)sender;
- (IBAction)addRemote:(id)sender;

@end
