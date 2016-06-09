#import "XTSideBarOutlineView.h"
#import "XTHistoryViewController.h"
#import "XTSideBarDataSource.h"
#import "Xit-Swift.h"

@implementation XTSideBarOutlineView

// The problem with overriding menuForEvent: is that right-clicking on an
// unselected item doesn't highlight it.
- (void)rightMouseDown:(NSEvent *)event
{
  const NSPoint localPoint =
      [self convertPoint:[event locationInWindow] fromView:nil];

  _contextMenuRow = [self rowAtPoint:localPoint];

  id item = [self itemAtRow:_contextMenuRow];
  NSMenu *menu = nil;

  if ([item isKindOfClass:[XTLocalBranchItem class]]) {
    menu = _controller.branchContextMenu;
  } else if ([item isKindOfClass:[XTTagItem class]]) {
    menu = _controller.tagContextMenu;
  } else if ([self parentForItem:item] ==
             [_controller.sideBarDS roots][XTRemotesGroupIndex]) {
    menu = _controller.remoteContextMenu;
  } else if ([item isKindOfClass:[XTStashItem class]]) {
    menu = _controller.stashContextMenu;
  }
  [self setMenu:menu];

  [super rightMouseDown:event];
  _contextMenuRow = -1;
}

@end
