#import "XTSideBarItem.h"

@class GTSubmodule;


@interface XTSubmoduleItem : XTSideBarItem

@property GTSubmodule *submodule;

- (id)initWithSubmodule:(GTSubmodule*)submodule;

@end
