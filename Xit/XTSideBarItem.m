#import "XTSideBarItem.h"

@implementation XTSideBarItem


- (id)initWithTitle:(NSString *)theTitle andSha:(NSString *)theSha
{
  self = [super init];
  if (self) {
    _title = theTitle;
    _sha = theSha;
    _children = [NSMutableArray array];
  }

  return self;
}

- (id)initWithTitle:(NSString *)theTitle
{
  return [self initWithTitle:theTitle andSha:nil];
}

- (NSString *)badge
{
  return self.title;
}

- (NSInteger)numberOfChildren
{
  return (NSInteger)[_children count];
}

- (id)childAtIndex:(NSInteger)index
{
  return _children[index];
}

- (void)addchild:(XTSideBarItem *)child
{
  [_children addObject:child];
}

- (BOOL)isItemExpandable
{
  return [_children count] > 0;
}

- (void)clean
{
  [_children removeAllObjects];
}

- (XTRefType)refType
{
  return XTRefTypeUnknown;
}

@end

@implementation XTStashItem

@end