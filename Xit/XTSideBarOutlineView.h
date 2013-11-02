#import <Cocoa/Cocoa.h>

@class XTHistoryViewController;

/**
  Subclassed in order to get the desired right-click behavior.
 */
@interface XTSideBarOutlineView : NSOutlineView
{
  IBOutlet XTHistoryViewController *controller;

  NSInteger contextMenuRow;
}

@property(readonly) NSInteger contextMenuRow;

@end
