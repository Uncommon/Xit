#import "XTSideBarItem.h"

@class GTSubmodule;


#import <Cocoa/Cocoa.h>
@interface XTSubmoduleItem : XTSideBarItem

@property GTSubmodule *submodule;

- (id)initWithSubmodule:(GTSubmodule*)submodule;

@end
