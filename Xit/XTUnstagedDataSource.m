#import "XTUnstagedDataSource.h"
#import "XTFileIndexInfo.h"
#import "XTModDateTracker.h"
#import "XTRepository+Parsing.h"

@implementation XTUnstagedDataSource

- (BOOL)shouldReloadForPaths:(NSArray *)paths
{
  if ([_indexTracker hasDateChanged])
    return YES;
  for (NSString *path in paths)
    if (![path hasPrefix:@".git/"])
      return YES;
  return NO;
}

- (void)reload
{
  [_items removeAllObjects];
  [_repo readUnstagedFilesWithBlock:^(NSString *name, NSString *status) {
    [_items addObject:
        [[XTFileIndexInfo alloc] initWithName:name andStatus:status]];
  }];
  [_table reloadData];
}

@end
