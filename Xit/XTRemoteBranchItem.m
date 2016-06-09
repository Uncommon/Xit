#import "XTRemoteBranchItem.h"

@implementation XTRemoteBranchItem


- (instancetype)initWithTitle:(NSString *)theTitle
                       remote:(NSString *)remoteName
                          sha:(NSString *)sha
{
  if ((self = [super initWithTitle:theTitle andSha:sha]) != nil)
    self.remote = remoteName;
  return self;
}

- (XTRefType)refType
{
  return XTRefTypeRemoteBranch;
}

@end
