#import <Cocoa/Cocoa.h>

@class XTHistoryViewController;

@interface XTSideBarOutlineView : NSOutlineView
{
  IBOutlet XTHistoryViewController *controller;

  NSInteger contextMenuRow;
}

@property(readonly) NSInteger contextMenuRow;

@end
