//
//  XTIndexDataSource.h
//  Xit
//
//  Created by German Laullon on 09/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XTRepository;

@interface XTUnstagedDataSource : NSObject <NSTableViewDataSource>
{
    @private
    XTRepository *repo;
    NSMutableArray *items;
    NSTableView *table;
}

- (NSArray *) items;
- (void) reload;
- (void) waitUntilReloadEnd;
- (void) setRepo:(XTRepository *)newRepo;

@end
