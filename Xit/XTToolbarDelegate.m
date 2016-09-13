#import "XTToolbarDelegate.h"
#import "Xit-Swift.h"


@implementation XTToolbarDelegate

- (void)finalizeItems
{
  for (NSToolbarItem *item in self.windowController.window.toolbar.items) {
    if ([item isKindOfClass:[XTWritingToolbarItem class]])
      [self.windowController.xtDocument.repository removeObserver:item
                                                       forKeyPath:@"isWriting"];
  }
}

- (void)toolbarWillAddItem:(NSNotification*)notification
{
  [super toolbarWillAddItem:notification];

  NSToolbarItem *item = (NSToolbarItem *)[notification userInfo][@"item"];
  
  if ([item isKindOfClass:[XTWritingToolbarItem class]])
    [self.windowController.xtDocument.repository
        addObserver:item
         forKeyPath:@"isWriting"
            options:NSKeyValueObservingOptionNew
            context:NULL];
}

- (void)toolbarDidRemoveItem:(NSNotification*)notification
{
  [super toolbarDidRemoveItem:notification];
  
  NSToolbarItem *item = (NSToolbarItem *)[notification userInfo][@"item"];
  
  if ([item isKindOfClass:[XTWritingToolbarItem class]])
    [self.windowController.xtDocument.repository removeObserver:item
                                                     forKeyPath:@"isWriting"];
}

- (BOOL)isFullHeightItem:(NSToolbarItem *)item
{
  if ([item.itemIdentifier isEqualToString:@"xit.status"]) {
    NSNib *nib = [[NSNib alloc] initWithNibNamed:@"XTStatusView" bundle:nil];
    NSArray *objects;

    NSAssert(nib, @"missing nib");
    [nib instantiateWithOwner:item topLevelObjects:&objects];
    for (id object in objects)
      if ([object isKindOfClass:[NSView class]])
        item.view = object;
    return YES;
  }
  return NO;
}

@end
