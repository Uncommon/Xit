//
//  XTHistoryDataSource.h
//  Xit
//
//  Created by German Laullon on 26/07/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Xit;

@interface XTHistoryDataSource : NSObject <NSTableViewDataSource>
{
@private
    Xit *repo;
    NSArray *items;
    NSTableView *table;
    BOOL cancel;
    dispatch_queue_t queue;
}

-(void)reload;
-(void)waitUntilReloadEnd;
-(void)setRepo:(Xit *)newRepo;

@end

