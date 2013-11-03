#import <Cocoa/Cocoa.h>

@class XTHistoryViewController;

/**
  Subclassed in order to get the desired right-click behavior.
 */
@interface XTSideBarOutlineView : NSOutlineView
{
  IBOutlet XTHistoryViewController *_controller;

  NSInteger _contextMenuRow;
}

@property(readonly) NSInteger contextMenuRow;

@end
