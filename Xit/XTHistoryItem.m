#import "XTHistoryItem.h"

@implementation XTHistoryItem


- (instancetype)init
{
  self = [super init];
  if (self) {
    self.parents = [NSMutableArray array];
  }

  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  return self;
}
@end
