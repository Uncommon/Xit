#import "XTHistoryDataSource.h"
#import "XTRepository.h"
#import "XTHistoryItem.h"
#import "XTStatusView.h"
#import "PBGitGrapher.h"
#import "PBGitHistoryGrapher.h"
#import "NSDate+Extensions.h"

@implementation XTHistoryDataSource


- (id)init
{
  self = [super init];
  if (self) {
    _items = [NSMutableArray array];
    _index = [NSMutableDictionary dictionary];
  }
  
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_repo removeObserver:self forKeyPath:@"selectedCommit"];
}

- (void)setRepo:(XTRepository *)newRepo
{
  _repo = newRepo;
  [_repo addReloadObserver:self selector:@selector(repoChanged:)];
  [_repo addObserver:self
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
    XTHistoryItem *item = _index[newSelectedCommit];
    if (item != nil) {
      [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:item.index]
          byExtendingSelection:NO];
      [_table scrollRowToVisible:item.index];
    } else {
      NSLog(@"commit '%@' not found!!", newSelectedCommit);
    }
  }
}

- (void)reload {
  if (_repo == nil)
    return;
  
  const BOOL selectHead = [_table selectedRow] == -1;
  
  [_repo executeOffMainThread:^{
    NSMutableArray *newItems = [NSMutableArray array];
    NSMutableDictionary *newIndex = [NSMutableDictionary dictionary];
    
    @try {
      [self loadHistoryIntoItems:newItems withIndex:newIndex];
    } @catch (NSException *exception) {
      return;
    }
    
    NSInteger headRow = - 1;
    
    if (selectHead) {
      NSString *headSHA = [_repo headSHA];
      __block NSInteger blockHeadRow = - 1;
      
      [newItems enumerateObjectsWithOptions:NSEnumerationConcurrent
                                 usingBlock:^(id obj, NSUInteger row,
                                              BOOL *stop) {
                                   if ([[(XTHistoryItem *)obj sha] isEqualToString:headSHA]) {
                                     blockHeadRow = row;
                                     * stop = YES;
                                   }
                                 }];
      headRow = blockHeadRow;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      _items = newItems;
      _index = newIndex;
      [_table reloadData];
      if (headRow != - 1)
        [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:headRow]
            byExtendingSelection:NO];
    });
  }];
}

- (void)loadHistoryIntoItems:(NSMutableArray *)newItems
                   withIndex:(NSMutableDictionary *)commitIndex
{
  NSArray *args = @[ @"--pretty=format:%H%n%P%n%cD%n%ce%n%s", @"--reverse",
                     @"--tags", @"--all", @"--topo-order" ];
  
  [XTStatusView updateStatus:@"Loading..."
                     command:[args componentsJoinedByString:@" "]
                      output:nil
               forRepository:_repo];
  [_repo getCommitsWithArgs:args enumerateCommitsUsingBlock:^(NSString *line) {
    // Guard Malloc pollutes the output; skip it
    if ([line hasPrefix:@"GuardMalloc[git"])
      return;
    [XTStatusView updateStatus:nil
                       command:nil
                        output:line
                 forRepository:_repo];
    
    NSArray *comps = [line componentsSeparatedByString:@"\n"];
    XTHistoryItem *item = [[XTHistoryItem alloc] init];
    
    if ([comps count] == 5) {
      item.sha = comps[0];
      NSString *parentsStr = comps[1];
      if (parentsStr.length > 0) {
        NSArray *parents = [parentsStr componentsSeparatedByString:@" "];
        
        [parents enumerateObjectsWithOptions:0
                                  usingBlock:^(id obj, NSUInteger idx,
                                               BOOL *stop) {
                                    NSString *parentSha = (NSString *)obj;
                                    XTHistoryItem *parent = commitIndex[parentSha];
                                    if (parent != nil) {
                                      [item.parents addObject:parent];
                                    } else {
                                      NSLog(@"parent with sha:'%@' not found for commit with "
                                            "sha:'%@' idx=%lu",
                                            parentSha, item.sha, item.index);
                                    }
                                  }];
      }
      item.repo = _repo;
      item.date = [NSDate dateFromRFC2822:comps[2]];
      item.email = comps[3];
      item.subject = comps[4];
      [newItems addObject:item];
      commitIndex[item.sha] = item;
    } else {
      [NSException raise:@"Invalid commit"
                  format:@"Line ***\n%@\n*** is invalid", line];
    }
  }
                      error:nil];
  
  if ([newItems count] > 0) {
    NSUInteger i = 0, j = [newItems count] - 1;
    
    while (i < j)
      [newItems exchangeObjectAtIndex:i++ withObjectAtIndex:j--];
  }
  
  PBGitGrapher *grapher = [[PBGitGrapher alloc] init];
  [newItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    XTHistoryItem *item = (XTHistoryItem *)obj;
    [grapher decorateCommit:item];
    item.index = idx;
  }];
  
  [XTStatusView updateStatus:[NSString stringWithFormat:@"%d commits loaded",
                              (int)[newItems count]]
                     command:nil
                      output:@""
               forRepository:_repo];
  NSLog(@"-> %lu", [newItems count]);
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [_items count];
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
                          row:(NSInteger)rowIndex
{
  XTHistoryItem *item = _items[rowIndex];

  return [item valueForKey:aTableColumn.identifier];
}

@end
