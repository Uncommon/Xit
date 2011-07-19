//
//  XTRemotesItem.m
//  Xit
//
//  Created by glaullon on 7/18/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import "XTRemotesItem.h"


@implementation XTRemotesItem

- (id)initWithTitle:(NSString *)theTitle
{
    self = [super initWithTitle:theTitle];
    if (self) {
        remotes=[NSMutableDictionary dictionary];
    }
    
    return self;
}

-(XTSideBarItem *)getRemote:(NSString *)remoteName
{
    return [remotes objectForKey:remoteName];
}

- (void)addchildren:(XTSideBarItem *)child
{
    [super addchildren:child];
    [remotes setObject:child forKey:[child title]];
}

@end
