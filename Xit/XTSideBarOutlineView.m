#import "XTSideBarOutlineView.h"
#import "XTHistoryViewController.h"
#import "XTLocalBranchItem.h"
#import "XTSideBarDataSource.h"
#import "XTTagItem.h"

@implementation XTSideBarOutlineView

@synthesize contextMenuRow;

// The problem with overriding menuForEvent: is that right-clicking on an
// unselected item doesn't highlight it.
- (void)rightMouseDown:(NSEvent *)event
{
  const NSPoint localPoint =
      [self convertPoint:[event locationInWindow] fromView:nil];

  contextMenuRow = [self rowAtPoint:localPoint];

  id item = [self itemAtRow:contextMenuRow];
  NSMenu *menu = nil;

  if ([item isKindOfClass:[XTLocalBranchItem class]]) {
    menu = controller.branchContextMenu;
  } else if ([item isKindOfClass:[XTTagItem class]]) {
    menu = controller.tagContextMenu;
  } else if ([self parentForItem:item] ==
             [controller.sideBarDS roots][XTRemotesGroupIndex]) {
    menu = controller.remoteContextMenu;
  } else if ([item isKindOfClass:[XTStashItem class]]) {
    menu = controller.stashContextMenu;
  }
  [self setMenu:menu];

  [super rightMouseDown:event];
  contextMenuRow = -1;
}

@end
