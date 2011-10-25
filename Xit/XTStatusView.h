//
//  XTStatusView.h
//  Xit
//
//  Created by David Catmull on 10/18/11.
//

#import <Cocoa/Cocoa.h>

@class XTRepository;

NSString *const XTStatusNotification;

@interface XTStatusView : NSView {
    IBOutlet NSTextField *label;
    IBOutlet NSPopover *popover;
    IBOutlet NSTextField *commandText;
    IBOutlet NSTextView *outputText;
    IBOutlet NSScrollView *outputScroll;
    XTRepository *repo;
}

// If status or command is non-nil, the text is updated.
// If output is nil, the output log is cleared.
// If output is non-nil, the string is appended to the log.
// Use output:@"" to leave the log as is.
+ (void)updateStatus:(NSString *)status command:(NSString *)command output:(NSString *)output forRepository:(XTRepository *)repo;

- (void)setRepo:(XTRepository *)repo;
- (IBAction)showOutput:(id)sender;

@end
