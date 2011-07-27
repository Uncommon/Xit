//
//  XTHistoryItem.m
//  Xit
//
//  Created by German Laullon on 26/07/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import "XTHistoryItem.h"

@implementation XTHistoryItem

@synthesize commit;
@synthesize date;
@synthesize email;
@synthesize subject;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

@end
