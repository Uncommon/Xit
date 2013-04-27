#import <Cocoa/Cocoa.h>

@class XTRepository;

@interface XTOutputViewController : NSViewController {
    IBOutlet NSTextField *commandText;
    IBOutlet NSTextView *outputText;
    IBOutlet NSScrollView *outputScroll;
    NSPopover *popover;
}

@property (strong) NSPopover *popover;

@end
