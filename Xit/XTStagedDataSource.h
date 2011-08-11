//
//  XTStagedDataSource.h
//  Xit
//
//  Created by German Laullon on 10/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Xit;

@interface XTStagedDataSource : NSObject <NSTableViewDataSource>
{
    @private
    Xit *repo;
    NSMutableArray *items;
    NSTableView *table;
}

- (NSArray *)items;
- (void)reload;
- (void)waitUntilReloadEnd;
- (void)setRepo:(Xit *)newRepo;

@end
