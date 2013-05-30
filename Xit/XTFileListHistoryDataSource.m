#import "XTFileListHistoryDataSource.h"
#import "XTRepository.h"
#import "XTHistoryItem.h"

@implementation XTFileListHistoryDataSource
@synthesize items;

- (id)init
{
  self = [super init];
  if (self) {
    items = [NSMutableArray array];
    index = [NSMutableDictionary dictionary];
  }

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [repo removeObserver:self forKeyPath:@"selectedCommit"];
}

- (void)setRepo:(XTRepository *)newRepo
{
  repo = newRepo;
  [repo addReloadObserver:self selector:@selector(repoChanged:)];
  [repo addObserver:self
         forKeyPath:@"selectedCommit"
            options:NSKeyValueObservingOptionNew
            context:nil];
  [self reload];
}

- (void)repoChanged:(NSNotification *)note
{
  NSArray *paths = [note userInfo][XTPathsKey];

  for (NSString *path in paths) {
    if ([path hasPrefix:@".git/logs/"]) {
      [self reload];
      break;
    }
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if ([keyPath isEqualToString:@"selectedCommit"]) {
    NSString *newSelectedCommit = change[NSKeyValueChangeNewKey];
    XTHistoryItem *item = index[newSelectedCommit];
    if (item != nil) {
      [table selectRowIndexes:[NSIndexSet indexSetWithIndex:item.index]
          byExtendingSelection:NO];
      [table scrollRowToVisible:item.index];
    } else {
      NSLog(@"commit '%@' not found!!", newSelectedCommit);
    }
  }
}

- (void)reload
{
    [repo executeOffMainThread:^{
      NSMutableArray *newItems = [NSMutableArray array];
      __block int idx = 0;
      void (^commitBlock)(NSString *) = ^(NSString *line) {
        NSArray *comps = [line componentsSeparatedByString:@"\n"];
        // If Guard Malloc is on, it pollutes the output
        if ([comps[0] hasPrefix:@"GuardMalloc["]) {
          NSMutableArray *filteredComps = [comps mutableCopy];
          while ([filteredComps[0] hasPrefix:@"GuardMalloc["])
            [filteredComps removeObjectAtIndex:0];
          comps = filteredComps;
        }
        if ([comps count] == 5) {
          XTHistoryItem *item = [[XTHistoryItem alloc] init];

          item.sha = comps[0];
          item.shortSha = comps[1];
          item.date = comps[2];
          item.email = comps[3];
          item.subject = comps[4];
          item.index = idx++;
          [newItems addObject:item];
          index[item.sha] = item;
        } else {
          [NSException raise:@"Invalid commint"
                      format:@"Line ***\n%@\n*** is invalid",
                             line];
        }
      };

      [repo getCommitsWithArgs:@[ @"--pretty=format:%H%n%h%n%ct%n%ce%n%s",
                                  @"--tags", @"--all", @"--topo-order" ]
          enumerateCommitsUsingBlock:commitBlock
                               error:nil];

      dispatch_async(dispatch_get_main_queue(), ^{
        items = newItems;
        [table reloadData];
      });
    }];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [items count];
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
                          row:(NSInteger)rowIndex
{
  XTHistoryItem *item = items[rowIndex];

  return item.shortSha;
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSLog(@"%@", aNotification);
  XTHistoryItem *item = items[table.selectedRow];
  repo.selectedCommit = item.sha;
}

@end
