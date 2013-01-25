//
//  XTSideBarItem.m
//  Xit
//
//  Created by German Laullon on 17/07/11.
//

#import "XTSideBarItem.h"

@implementation XTSideBarItem

@synthesize title;
@synthesize sha;

- (id)initWithTitle:(NSString *)theTitle andSha:(NSString *)theSha {
    self = [super init];
    if (self) {
        title = theTitle;
        sha = theSha;
        children = [NSMutableArray array];
    }

    return self;
}

- (id)initWithTitle:(NSString *)theTitle {
    return [self initWithTitle:theTitle andSha:nil];
}

- (NSString *)badge {
    return self.title;
}

- (NSInteger)numberOfChildren {
    return (NSInteger)[children count];
}

- (id)childAtIndex:(NSInteger)index {
    return [children objectAtIndex:index];
}

- (void)addchild:(XTSideBarItem *)child {
    [children addObject:child];
}

- (BOOL)isItemExpandable {
    return [children count] > 0;
}

- (void)clean {
    [children removeAllObjects];
}

- (XTRefType)refType {
  return XTRefTypeUnknown;
}

@end

@implementation XTStashItem

@end