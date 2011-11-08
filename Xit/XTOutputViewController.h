//
//  XTOutputViewController.h
//  Xit
//
//  Created by David Catmull on 10/26/11.
//

#import <Cocoa/Cocoa.h>

@class XTRepository;

@interface XTOutputViewController : NSViewController {
    IBOutlet NSTextField *commandText;
    IBOutlet NSTextView *outputText;
    IBOutlet NSScrollView *outputScroll;
    NSPopover *popover;
}

@property (assign) NSPopover *popover;

@end
