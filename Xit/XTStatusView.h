#import <Cocoa/Cocoa.h>

@class XTOutputViewController;
@class XTRepository;

extern NSString *const XTStatusNotification;
extern NSString *const XTStatusTextKey;
extern NSString *const XTStatusCommandKey;
extern NSString *const XTStatusOutputKey;

@interface XTStatusView : NSView<NSPopoverDelegate> {
  IBOutlet NSTextField *label;
  IBOutlet NSPopover *popover;
  IBOutlet NSWindow *detachedWindow;
  IBOutlet XTOutputViewController *outputController;
  IBOutlet XTOutputViewController *detachedController;
  XTRepository *repo;
  NSGradient *fillGradient, *strokeGradient;
}

// If status or command is non-nil, the text is updated.
// If output is nil, the output log is cleared.
// If output is non-nil, the string is appended to the log.
// Use output:@"" to leave the log as is.
+ (void)updateStatus:(NSString *)status
             command:(NSString *)command
              output:(NSString *)output
       forRepository:(XTRepository *)repo;

- (void)setRepo:(XTRepository *)repo;
- (IBAction)showOutput:(id)sender;

@end
