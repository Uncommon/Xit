#import "XTToolbarDelegate.h"

@implementation XTToolbarDelegate

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
