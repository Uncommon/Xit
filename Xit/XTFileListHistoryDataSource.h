//
//  XTFileListHistoryDataSource.h
//  Xit
//
//  Created by German Laullon on 15/09/11.
//

#import <Foundation/Foundation.h>

@class XTRepository;
@class XTHistoryItem;

@interface XTFileListHistoryDataSource : NSObject <NSTableViewDataSource>
{
    @private
    XTRepository *repo;
    NSArray *items;
    IBOutlet NSTableView *table;
    NSMutableDictionary *index;
}

@property (readonly) NSArray *items;

- (void)reload;
- (void)setRepo:(XTRepository *)newRepo;
@end
