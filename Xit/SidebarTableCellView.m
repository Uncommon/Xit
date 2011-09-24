//
//  SidebarTableCellView.h
//  Xit
//
//  Created by David Catmull on 09/23/11.
//  Based on the SidebarDemo sample code from Apple
//

#import "SidebarTableCellView.h"


@implementation SidebarTableCellView

@synthesize button = _button;

- (void)awakeFromNib {
    // We want it to appear "inline"
    [[self.button cell] setBezelStyle:NSInlineBezelStyle];
}

- (void)dealloc {
    self.button = nil;
    [super dealloc];
}

// The standard rowSizeStyle does some specific layout for us. To customize
// layout for our button, we first call super and then modify things
- (void)viewWillDraw {
    [super viewWillDraw];
    if (![self.button isHidden]) {
        [self.button sizeToFit];

        NSRect textFrame = self.textField.frame;
        NSRect buttonFrame = self.button.frame;

        buttonFrame.origin.x = NSWidth(self.frame) - NSWidth(buttonFrame);
        self.button.frame = buttonFrame;
        textFrame.size.width = NSMinX(buttonFrame) - NSMinX(textFrame);
        self.textField.frame = textFrame;
    }
}

@end
