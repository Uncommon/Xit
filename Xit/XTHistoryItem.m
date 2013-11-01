#import "XTHistoryItem.h"

@implementation XTHistoryItem


- (id)init
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
