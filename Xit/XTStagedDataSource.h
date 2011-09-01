//
//  XTStagedDataSource.h
//  Xit
//
//  Created by German Laullon on 10/08/11.
//

#import <Foundation/Foundation.h>

@class XTRepository;

@interface XTStagedDataSource : NSObject <NSTableViewDataSource>
{
    @private
    XTRepository *repo;
    NSMutableArray *items;
    NSTableView *table;
}

- (NSArray *)items;
- (void)reload;
- (void)waitUntilReloadEnd;
- (void)setRepo:(XTRepository *)newRepo;

@end
