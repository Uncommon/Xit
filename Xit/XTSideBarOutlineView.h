#import <Cocoa/Cocoa.h>

@class XTHistoryViewController;

@interface XTSideBarOutlineView : NSOutlineView
{
  IBOutlet XTHistoryViewController *_controller;

  NSInteger _contextMenuRow;
}

@property(readonly) NSInteger contextMenuRow;

@end
