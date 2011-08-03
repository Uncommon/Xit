//
//  XTHistoryItem.m
//  Xit
//
//  Created by German Laullon on 26/07/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import "XTHistoryItem.h"

@implementation XTHistoryItem

@synthesize sha;
@synthesize parents;
@synthesize childrens;
@synthesize date;
@synthesize email;
@synthesize subject;
@synthesize lineInfo;

- (id)init
{
    self = [super init];
    if (self) {
        [self setParents:[NSMutableArray array]];
        [self setChildrens:[NSMutableArray array]];
    }
    
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}
@end
