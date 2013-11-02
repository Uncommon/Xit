#import "XTStagedDataSource.h"
#import "XTModDateTracker.h"
#import "XTRepository+Parsing.h"
#import "XTFileIndexInfo.h"

@implementation XTStagedDataSource

- (BOOL)shouldReloadForPaths:(NSArray *)paths
{
  return [_indexTracker hasDateChanged];
}

- (void)reload
{
  [_repo executeOffMainThread:^{
	  NSMutableArray *newItems = [NSMutableArray array];

	  [_repo readStagedFilesWithBlock:^(NSString *name, NSString *status) {
		  XTFileIndexInfo *fileInfo =
				  [[XTFileIndexInfo alloc] initWithName:name andStatus:status];
		  [newItems addObject:fileInfo];
	  }];
	  dispatch_async(dispatch_get_main_queue(), ^{
		  _items = newItems;
		  [_table reloadData];
	  });
  }];
}

@end
