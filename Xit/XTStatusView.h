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

// Changes the status text and clears the output
+ (void)setStatus:(NSString *)status forRepository:(XTRepository *)repo;

// Appends output text without changing the status text
+ (void)addOutput:(NSString *)output forRepository:(XTRepository *)repo;

// Changes the status text without clearing the output
+ (void)finishStatus:(NSString *)status forRepository:(XTRepository *)repo;

- (void)setRepo:(XTRepository *)repo;
- (IBAction)showOutput:(id)sender;

@end
