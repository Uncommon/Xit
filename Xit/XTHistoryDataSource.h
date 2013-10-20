#import <Foundation/Foundation.h>

@class XTRepository;
@class XTHistoryItem;

#import <Cocoa/Cocoa.h>
@interface XTHistoryDataSource
    : NSObject<NSTableViewDataSource, NSTableViewDelegate> {
 @private
  XTRepository *repo;
  IBOutlet NSTableView *table;
  NSMutableDictionary *index;
}

@property(readonly) NSArray *items;

- (void)reload;
- (void)setRepo:(XTRepository *)newRepo;
@end

