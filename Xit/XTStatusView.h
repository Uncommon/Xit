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
    IBOutlet NSTextView *outputText;
    XTRepository *repo;
}

+ (void)notifyStatus:(NSString *)status forRepository:(XTRepository *)repo;

- (void)setRepo:(XTRepository *)repo;
- (IBAction)showOutput:(id)sender;

@end
