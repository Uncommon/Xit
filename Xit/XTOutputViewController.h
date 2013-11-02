#import <Cocoa/Cocoa.h>

@class XTRepository;

@interface XTOutputViewController : NSViewController {
  IBOutlet NSTextField *_commandText;
  IBOutlet NSTextView *_outputText;
  IBOutlet NSScrollView *_outputScroll;
}

@property(strong) NSPopover *popover;

@end
