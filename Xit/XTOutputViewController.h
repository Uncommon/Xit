#import <Cocoa/Cocoa.h>

@class XTRepository;

#import <Cocoa/Cocoa.h>
@interface XTOutputViewController : NSViewController {
  IBOutlet NSTextField *commandText;
  IBOutlet NSTextView *outputText;
  IBOutlet NSScrollView *outputScroll;
  NSPopover *popover;
}

@property(strong) NSPopover *popover;

@end
