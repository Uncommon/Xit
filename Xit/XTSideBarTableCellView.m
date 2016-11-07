//  Based on the SidebarDemo sample code from Apple

#import "XTSideBarTableCellView.h"

@implementation XTSideBarTableCellView

// The standard rowSizeStyle does some specific layout for us. To customize
// layout for our button, we first call super and then modify things
- (void)drawRect:(NSRect)dirtyRect
{
  [super drawRect:dirtyRect];
}

@end
