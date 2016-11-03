#import "Xit-Swift.h"
#import "XTSideBarOutlineView.h"
#import "XTHistoryViewController.h"
#import "XTSideBarDataSource.h"

@interface XTSideBarOutlineView ()

@property(readwrite) NSInteger contextMenuRow;

@end


@implementation XTSideBarOutlineView

// The problem with overriding menuForEvent: is that right-clicking on an
// unselected item doesn't highlight it.
- (void)rightMouseDown:(NSEvent *)event
{
  const NSPoint localPoint =
      [self convertPoint:event.locationInWindow fromView:nil];

  self.contextMenuRow = [self rowAtPoint:localPoint];

  id item = [self itemAtRow:self.contextMenuRow];
  NSMenu *menu = nil;

  if ([item isKindOfClass:[XTRemoteBranchItem class]]) {
    menu = [self prepBranchMenuForLocal:NO];
  } else if ([item isKindOfClass:[XTLocalBranchItem class]]) {
    menu = [self prepBranchMenuForLocal:YES];
  } else if ([item isKindOfClass:[XTTagItem class]]) {
    menu = self.controller.tagContextMenu;
  } else if ([self parentForItem:item] ==
             self.controller.sidebarDS.roots[XTGroupIndexRemotes]) {
    menu = self.controller.remoteContextMenu;
  } else if ([item isKindOfClass:[XTStashItem class]]) {
    menu = self.controller.stashContextMenu;
  }
  self.menu = menu;

  [super rightMouseDown:event];
  self.contextMenuRow = -1;
}

- (NSMenu*)prepBranchMenuForLocal:(BOOL)local
{
  // Renaming remote branches is not implemented.
  for (NSMenuItem *item in _controller.branchContextMenu.itemArray) {
    if (item.action == @selector(renameBranch:)) {
      item.hidden = !local;
      break;
    }
  }
  return self.controller.branchContextMenu;
}

@end
