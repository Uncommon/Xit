#import "XTLocalBranchItem.h"

@implementation XTLocalBranchItem

- (BOOL)isItemExpandable
{
  return NO;
}

- (XTRefType)refType
{
  return XTRefTypeBranch;
}

@end
