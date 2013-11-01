#import "XTStagingDataSourceBase.h"
#import "XTFileIndexInfo.h"
#import "XTModDateTracker.h"
#import "XTRepository.h"

@implementation XTStagingDataSourceBase

- (id)init
{
  self = [super init];
  if (self) {
    _items = [NSMutableArray array];
  }

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setRepo:(XTRepository *)newRepo
{
  _repo = newRepo;
  [_repo addReloadObserver:self selector:@selector(repoChanged:)];
  _indexTracker = [[XTModDateTracker alloc] initWithPath:
          [[_repo.repoURL path] stringByAppendingPathComponent:@".git/index"]];
  [self reload];
}

- (void)repoChanged:(NSNotification *)note
{
  NSArray *paths = [note userInfo][XTPathsKey];

  if (![self shouldReloadForPaths:paths])
    return;

  // Recursion can happen if reloading uses git calls that trigger the file
  // system notification.
  if (! _reloading) {
    _reloading = YES;
    [self reload];
    _reloading = NO;
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
  return _items;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  _table = aTableView;
  return [_items count];
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)column
                          row:(NSInteger)rowIndex
{
  if (rowIndex >= [_items count])
    return nil;

  XTFileIndexInfo *item = _items[rowIndex];
  NSString *title = [item valueForKey:column.identifier];

  return [@"  " stringByAppendingString:title];
}

@end
