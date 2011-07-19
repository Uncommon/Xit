//
//  XTSideBarItem.m
//  Xit
//
//  Created by German Laullon on 17/07/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import "XTSideBarItem.h"

@implementation XTSideBarItem

- (id)initWithTitle:(NSString *)theTitle
{
    self = [super init];
    if (self) {
        title=theTitle;
        childrens=[NSMutableArray array];
    }
    
    return self;
}

- (NSString *)title
{
    return title;
}

- (NSInteger)numberOfChildrens
{
    return (NSInteger)[childrens count];
}

- (id)children:(NSInteger)index
{
    return [childrens objectAtIndex:index];
}

- (void)addchildren:(XTSideBarItem *)child
{
    [childrens addObject:child];
}

-(BOOL)isItemExpandable
{
    return [childrens count]>0;
}

@end
