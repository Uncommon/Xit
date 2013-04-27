#import "XTTagItem.h"

@implementation XTTagItem

- (BOOL)isItemExpandable {
    return NO;
}

- (XTRefType)refType {
  return XTRefTypeTag;
}

@end
