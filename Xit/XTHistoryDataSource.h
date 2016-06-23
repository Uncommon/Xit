#import <Foundation/Foundation.h>

@class XTWindowController;
@class XTHistoryItem;
@class XTRepository;

/**
  Data source for the history list.
 */
@interface XTHistoryDataSource
    : NSObject<NSTableViewDataSource, NSTableViewDelegate> {
 @private
  XTRepository *_repo;
  IBOutlet NSTableView *_table;
  NSMutableDictionary *_index;
}

@property(readonly) NSOrderedSet<NSString*> *shas;
@property(weak, nonatomic) XTWindowController *controller;

- (void)reload;
- (void)setRepo:(XTRepository*)newRepo;

- (XTHistoryItem*)itemAtIndex:(NSUInteger)index;

@end

