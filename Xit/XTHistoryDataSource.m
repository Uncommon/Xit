#import "XTHistoryDataSource.h"
#import "XTDocController.h"
#import "XTHistoryItem.h"
#import "XTRepository.h"
#import "XTStatusView.h"
#import "PBGitGrapher.h"
#import "PBGitHistoryGrapher.h"
#import "NSDate+Extensions.h"

@implementation XTHistoryDataSource

- (id)init
{
  self = [super init];
  if (self) {
    _shas = [NSOrderedSet orderedSet];
    _index = [NSMutableDictionary dictionary];
  }
  
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_controller removeObserver:self forKeyPath:@"selectedCommitSHA"];
}

- (void)setRepo:(XTRepository*)newRepo
{
  _repo = newRepo;
  [_repo addReloadObserver:self selector:@selector(repoChanged:)];
  [self reload];
}

- (void)setController:(XTDocController*)controller
{
  _controller = controller;
  [controller addObserver:self
               forKeyPath:@"selectedCommitSHA"
                  options:NSKeyValueObservingOptionNew
                  context:nil];
}

- (XTHistoryItem*)itemAtIndex:(NSUInteger)index
{
  return _index[self.shas[index]];
}

- (void)repoChanged:(NSNotification*)note
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
  if ([keyPath isEqualToString:@"selectedCommitSHA"]) {
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
    NSMutableOrderedSet<NSString*> *newShas = [NSMutableOrderedSet orderedSet];
    NSMutableDictionary *newIndex = [NSMutableDictionary dictionary];
    
    @try {
      [self loadHistoryIntoShas:newShas withIndex:newIndex];
    } @catch (NSException *exception) {
      return;
    }
    
    const NSUInteger headRow = selectHead ?
        [newShas indexOfObject:_repo.headSHA] : NSNotFound;
    
    dispatch_async(dispatch_get_main_queue(), ^{
      _shas = newShas;
      _index = newIndex;
      [_table reloadData];
      if (headRow != NSNotFound)
        [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:headRow]
            byExtendingSelection:NO];
    });
  }];
}

- (void)loadHistoryIntoShas:(NSMutableOrderedSet<NSString*>*)newShas
                  withIndex:(NSMutableDictionary*)commitIndex
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
      [newShas insertObject:item.sha atIndex:0];
      commitIndex[item.sha] = item;
    } else {
      [NSException raise:@"Invalid commit"
                  format:@"Line ***\n%@\n*** is invalid", line];
    }
  }
                      error:nil];
  
  PBGitGrapher *grapher = [[PBGitGrapher alloc] init];

  [newShas enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    [grapher decorateCommit:commitIndex[obj]];
  }];
  
  [XTStatusView updateStatus:[NSString stringWithFormat:@"%d commits loaded",
                                                        (int)[newShas count]]
                     command:nil
                      output:@""
               forRepository:_repo];
  NSLog(@"-> %lu", [newShas count]);
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [_shas count];
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
                          row:(NSInteger)rowIndex
{
  XTHistoryItem *item = _index[_shas[rowIndex]];

  return [item valueForKey:aTableColumn.identifier];
}

@end
