#import "XTStagingDataSourceBase.h"
#import "XTFileIndexInfo.h"
#import "XTModDateTracker.h"
#import "XTRepository.h"

@implementation XTStagingDataSourceBase

- (id)init
{
  self = [super init];
  if (self) {
    items = [NSMutableArray array];
  }

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setRepo:(XTRepository *)newRepo
{
  repo = newRepo;
  [repo addReloadObserver:self selector:@selector(repoChanged:)];
  indexTracker = [[XTModDateTracker alloc] initWithPath:
          [[repo.repoURL path] stringByAppendingPathComponent:@".git/index"]];
  [self reload];
}

- (void)repoChanged:(NSNotification *)note
{
  NSArray *paths = [note userInfo][XTPathsKey];

  if (![self shouldReloadForPaths:paths])
    return;

  // Recursion can happen if reloading uses git calls that trigger the file
  // system notification.
  if (!reloading) {
    reloading = YES;
    [self reload];
    reloading = NO;
  }
}

- (BOOL)shouldReloadForPaths:(NSArray *)paths
{
  return YES;
}

- (void)reload
{
  // For subclasses.
}

- (NSArray *)items
{
  return items;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  table = aTableView;
  return [items count];
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)column
                          row:(NSInteger)rowIndex
{
  if (rowIndex >= [items count])
    return nil;

  XTFileIndexInfo *item = items[rowIndex];
  NSString *title = [item valueForKey:column.identifier];

  return [@"  " stringByAppendingString:title];
}

@end