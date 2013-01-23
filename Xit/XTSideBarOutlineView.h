#import <Cocoa/Cocoa.h>

@class XTHistoryViewController;

@interface XTSideBarOutlineView : NSOutlineView
{
    IBOutlet XTHistoryViewController *controller;
    IBOutlet NSMenu *branchContextMenu;
    IBOutlet NSMenu *remoteContextMenu;
    IBOutlet NSMenu *tagContextMenu;

    NSInteger contextMenuRow;
}

@property (readonly) NSInteger contextMenuRow;

@end
