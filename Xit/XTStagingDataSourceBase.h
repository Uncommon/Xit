#import <Foundation/Foundation.h>

@class XTModDateTracker;
@class XTRepository;

@interface XTStagingDataSourceBase : NSObject<NSTableViewDataSource> {
 @protected
  XTRepository *_repo;
  NSMutableArray *_items;
  NSTableView *_table;
  BOOL _reloading;
  XTModDateTracker *_indexTracker;
}

- (NSArray *)items;
- (void)reload;
- (void)setRepo:(XTRepository *)newRepo;
- (BOOL)shouldReloadForPaths:(NSArray *)paths;

@end
