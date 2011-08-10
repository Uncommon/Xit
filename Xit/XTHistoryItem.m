//
//  XTHistoryItem.m
//  Xit
//
//  Created by German Laullon on 26/07/11.
//

#import "XTHistoryItem.h"

@implementation XTHistoryItem

@synthesize sha;
@synthesize parents;
@synthesize date;
@synthesize email;
@synthesize subject;
@synthesize lineInfo;
@synthesize index;

- (id) init {
    self = [super init];
    if (self) {
        self.parents = [NSMutableArray array];
    }

    return self;
}

- (id) copyWithZone:(NSZone *)zone {
    return [self retain];
}
@end
