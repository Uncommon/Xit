#import "Xit-Swift.h"
#import "XTSideBarOutlineView.h"
#import "XTHistoryViewController.h"
#import "XTSideBarDataSource.h"

@implementation XTSideBarOutlineView

// The problem with overriding menuForEvent: is that right-clicking on an
// unselected item doesn't highlight it.
- (void)rightMouseDown:(NSEvent *)event
{
  const NSPoint localPoint =
      [self convertPoint:event.locationInWindow fromView:nil];

  _contextMenuRow = [self rowAtPoint:localPoint];

  id item = [self itemAtRow:_contextMenuRow];
  NSMenu *menu = nil;

  if ([item isKindOfClass:[XTRemoteBranchItem class]]) {
    menu = [self prepBranchMenuForLocal:NO];
  } else if ([item isKindOfClass:[XTLocalBranchItem class]]) {
    menu = [self prepBranchMenuForLocal:YES];
  } else if ([item isKindOfClass:[XTTagItem class]]) {
    menu = _controller.tagContextMenu;
  } else if ([self parentForItem:item] ==
             _controller.sideBarDS.roots[XTGroupIndexRemotes]) {
    menu = _controller.remoteContextMenu;
  } else if ([item isKindOfClass:[XTStashItem class]]) {
    menu = _controller.stashContextMenu;
  }
  self.menu = menu;

  [super rightMouseDown:event];
  _contextMenuRow = -1;
}

- (NSMenu*)prepBranchMenuForLocal:(BOOL)local
{
  // Renaming remote branches is not implemented.
  for (NSMenuItem *item in _controller.branchContextMenu.itemArray) {
    if (item.action == @selector(renameBranch:))
      item.hidden = !local;
  }
  return _controller.branchContextMenu;
}

@end
