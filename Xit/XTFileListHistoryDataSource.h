#import <Foundation/Foundation.h>

@class XTRepository;
@class XTHistoryItem;

@interface XTFileListHistoryDataSource
    : NSObject<NSTableViewDataSource, NSTableViewDelegate> {
 @private
  XTRepository *repo;
  NSArray *items;
  IBOutlet NSTableView *table;
  NSMutableDictionary *index;
}

@property(readonly) NSArray *items;

- (void)reload;
- (void)setRepo:(XTRepository *)newRepo;
@end
