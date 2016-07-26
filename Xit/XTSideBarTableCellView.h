//  Based on the SidebarDemo sample code from Apple

#import <Cocoa/Cocoa.h>

@class XTSideBarItem;

@interface XTSideBarTableCellView : NSTableCellView

@property(strong) IBOutlet NSImageView *statusImage;
@property(weak) XTSideBarItem *item;

@end
