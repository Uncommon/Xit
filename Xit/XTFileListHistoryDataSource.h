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
    BOOL useFile;
}

@property (readonly) NSArray *items;
@property (assign) NSString *file;
@property (assign) BOOL useFile;

- (void)reload;
- (void)setRepo:(XTRepository *)newRepo;
@end
