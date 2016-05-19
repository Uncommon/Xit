#import <Cocoa/Cocoa.h>

@class XTDocument;
@class XTHistoryViewController;
@class XTRepository;
@class XTStatusView;

@interface XTDocController : NSWindowController {
  IBOutlet XTHistoryViewController *_historyView;
  IBOutlet NSProgressIndicator *_activity;
  XTDocument *_xtDocument;
}

@property NSString *selectedCommitSHA;

- (id)initWithDocument:(XTDocument *)doc;

- (IBAction)refresh:(id)sender;
- (IBAction)newTag:(id)sender;
- (IBAction)newBranch:(id)sender;
- (IBAction)addRemote:(id)sender;

@end
