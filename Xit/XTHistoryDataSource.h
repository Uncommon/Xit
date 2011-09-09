//
//  XTHistoryDataSource.h
//  Xit
//
//  Created by German Laullon on 26/07/11.
//

#import <Foundation/Foundation.h>

@class XTRepository;
@class XTHistoryItem;

@interface XTHistoryDataSource : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
    @private
    XTRepository *repo;
    NSArray *items;
    IBOutlet NSTableView *table;
    BOOL cancel;
    NSMutableDictionary *index;
}

@property (readonly) NSArray *items;

- (void)reload;
- (void)setRepo:(XTRepository *)newRepo;
@end

