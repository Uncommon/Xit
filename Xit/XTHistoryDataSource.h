//
//  XTHistoryDataSource.h
//  Xit
//
//  Created by German Laullon on 26/07/11.
//

#import <Foundation/Foundation.h>

@class Xit;
@class XTHistoryItem;

@interface XTHistoryDataSource : NSObject <NSTableViewDataSource,NSTableViewDelegate>
{
@private
    Xit *repo;
    NSArray *items;
    NSTableView *table;
    BOOL cancel;
    dispatch_queue_t queue;
    NSMutableDictionary *index;
}

@property(readonly)NSArray *items;

-(void)reload;
-(void)waitUntilReloadEnd;
-(void)setRepo:(Xit *)newRepo;
@end

