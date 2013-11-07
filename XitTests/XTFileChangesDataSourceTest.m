#import "XTTest.h"
#import "XTFileChangesDataSource.h"
#include "XTQueueUtils.h"

@interface XTFileChangesDataSourceTest : XTTest

@end

@implementation XTFileChangesDataSourceTest

- (void)testInitialCommit
{
  XTFileChangesDataSource *dataSource = [[XTFileChangesDataSource alloc] init];

  repository.selectedCommit = repository.headSHA;
  dataSource.repository = repository;
  [self waitForRepoQueue];
  WaitForQueue(dispatch_get_main_queue());

  STAssertEquals(
      [dataSource outlineView:nil numberOfChildrenOfItem:nil], 1L, nil);

  id item1 = [dataSource outlineView:nil child:0 ofItem:nil];

  STAssertEqualObjects([dataSource pathForItem:item1], @"file1.txt", nil);
  STAssertFalse([dataSource outlineView:nil isItemExpandable:item1], nil);
  STAssertEquals([dataSource changeForItem:item1], XitChangeAdded, nil);
}

@end
