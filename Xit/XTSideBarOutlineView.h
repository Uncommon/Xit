#import <Cocoa/Cocoa.h>

@class XTSidebarController;

/**
  Subclassed in order to get the desired right-click behavior.
 */
@interface XTSideBarOutlineView : NSOutlineView

@property(weak) IBOutlet XTSidebarController *controller;
@property(readonly) NSInteger contextMenuRow;

@end
