//  Based on the SidebarDemo sample code from Apple

#import <Cocoa/Cocoa.h>

@class XTSideBarItem;

@interface XTSideBarTableCellView : NSTableCellView

@property(strong) IBOutlet NSImageView *statusImage;
@property(strong) IBOutlet NSButton *statusText;
@property(weak) XTSideBarItem *item;

@end
