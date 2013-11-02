#import "FHTLCDStatusView.h"

@class XTOutputViewController;
@class XTRepository;

extern NSString *const XTStatusNotification;
extern NSString *const XTStatusTextKey;
extern NSString *const XTStatusCommandKey;
extern NSString *const XTStatusOutputKey;

/**
  The view for displaying status information in the toolbar.
 */
@interface XTStatusView : FHTLCDStatusView {
  IBOutlet NSTextField *label;
  IBOutlet NSPopover *popover;
  IBOutlet NSWindow *detachedWindow;
  IBOutlet XTOutputViewController *outputController;
  IBOutlet XTOutputViewController *detachedController;
  XTRepository *repo;
}

/**
  If \a status or \a command is non-nil, the text is updated.
  \param status Text to display in the view
  \param command The Git command that was executed
  \param output If nil, the log is cleared. Otherwise the string is appended
  to the log.
 */
+ (void)updateStatus:(NSString *)status
             command:(NSString *)command
              output:(NSString *)output
       forRepository:(XTRepository *)repo;

- (void)setRepo:(XTRepository *)repo;
- (IBAction)showOutput:(id)sender;

@end
