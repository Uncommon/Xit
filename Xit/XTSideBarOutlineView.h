#import <Cocoa/Cocoa.h>

@class XTHistoryViewController;

#import <Cocoa/Cocoa.h>
@interface XTSideBarOutlineView : NSOutlineView
{
  IBOutlet XTHistoryViewController *controller;

  NSInteger contextMenuRow;
}

@property(readonly) NSInteger contextMenuRow;

@end
