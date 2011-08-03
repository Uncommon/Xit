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
@synthesize date;
@synthesize email;
@synthesize subject;
@synthesize lineInfo;

- (id)init
{
    self = [super init];
    if (self) {
    }
    
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}
@end
