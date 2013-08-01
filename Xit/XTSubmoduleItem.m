#import "XTSubmoduleItem.h"
#import <ObjectiveGit/ObjectiveGit.h>

@implementation XTSubmoduleItem

- (id)initWithSubmodule:(GTSubmodule*)submodule
{
  if ((self = [super init]) != nil) {
    _submodule = submodule;
  }
  return self;
}

- (NSString*)title
{
  return self.submodule.name;
}

@end
