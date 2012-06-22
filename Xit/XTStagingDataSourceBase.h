//
//  XTStagedDataSource.h
//  Xit
//
//  Created by David Catmull on 6/22/11.
//

#import <Foundation/Foundation.h>

@class XTRepository;

@interface XTStagingDataSourceBase : NSObject <NSTableViewDataSource>
{
    @protected
    XTRepository *repo;
    NSMutableArray *items;
    NSTableView *table;
}

- (NSArray *)items;
- (void)reload;
- (void)setRepo:(XTRepository *)newRepo;

@end
