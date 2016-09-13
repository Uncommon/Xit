#import "FHTDelegate.h"

@class XTWindowController;

@interface XTToolbarDelegate : FHTDelegate

@property (weak) IBOutlet XTWindowController *windowController;

- (void)finalizeItems;

@end
