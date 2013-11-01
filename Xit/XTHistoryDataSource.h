#import <Foundation/Foundation.h>

@class XTRepository;
@class XTHistoryItem;

@interface XTHistoryDataSource
    : NSObject<NSTableViewDataSource, NSTableViewDelegate> {
 @private
  XTRepository *_repo;
  IBOutlet NSTableView *_table;
  NSMutableDictionary *_index;
}

@property(readonly) NSArray *items;

- (void)reload;
- (void)setRepo:(XTRepository *)newRepo;
@end

