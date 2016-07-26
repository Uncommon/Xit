//  Based on the SidebarDemo sample code from Apple

#import "XTSideBarTableCellView.h"

@implementation XTSideBarTableCellView

// The standard rowSizeStyle does some specific layout for us. To customize
// layout for our button, we first call super and then modify things
- (void)viewWillDraw
{
  [super viewWillDraw];
  if (self.statusImage.image != nil) {
    NSRect textFrame = self.textField.frame;
    NSRect imageFrame = self.statusImage.frame;

    imageFrame.origin.x = NSWidth(self.frame) - NSWidth(imageFrame) + 2;
    self.statusImage.frame = imageFrame;
    textFrame.size.width = NSMinX(imageFrame) - NSMinX(textFrame);
    self.textField.frame = textFrame;
  }
}

@end
