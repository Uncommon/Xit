#import "FHTLCDStatusView.h"

NS_ASSUME_NONNULL_BEGIN

@class XTOutputViewController;
@class XTRepository;

extern NSString *const XTStatusNotification;
extern NSString *const XTStatusTextKey;
extern NSString *const XTStatusProgressKey;
extern NSString *const XTStatusCommandKey;
extern NSString *const XTStatusOutputKey;

/**
  The view for displaying status information in the toolbar.
 */
@interface XTStatusView : FHTLCDStatusView {
  IBOutlet NSTextField *label;
  IBOutlet NSProgressIndicator *progressBar;
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
+ (void)updateStatus:(nullable NSString*)status
             command:(nullable NSString*)command
              output:(nullable NSString*)output
       forRepository:(XTRepository *)repo
  NS_SWIFT_NAME(update(status:command:output:repository:));

/**
   If \a status is non-nil, the text is updated.
   \param status Text to display in the view
   \param progress Pass a negative number to hide the progress bar, or between
   0 and 1.0 to show progress.
 */
+ (void)updateStatus:(nullable NSString*)status
            progress:(float)progress
       forRepository:(XTRepository *)repo
  NS_SWIFT_NAME(update(status:progress:repository:));

- (void)setRepo:(XTRepository *)repo;
- (IBAction)showOutput:(id)sender;

@end

NS_ASSUME_NONNULL_END
