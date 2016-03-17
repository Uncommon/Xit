#import "XTTest.h"
#import "XTFileChangesDataSource.h"
#include "XTQueueUtils.h"

@interface XTFileChangesDataSourceTest : XTTest

@end

@implementation XTFileChangesDataSourceTest

- (void)testInitialCommit
{
  XTFileChangesDataSource *dataSource = [[XTFileChangesDataSource alloc] init];
  NSOutlineView *outlineView = [[NSOutlineView alloc] init];

  repository.selectedCommit = repository.headSHA;
  dataSource.repository = repository;
  [self waitForRepoQueue];
  WaitForQueue(dispatch_get_main_queue());

  XCTAssertEqual(
      [dataSource outlineView:outlineView numberOfChildrenOfItem:nil], 1L);

  id item1 = [dataSource outlineView:outlineView child:0 ofItem:nil];

  XCTAssertEqualObjects([dataSource pathForItem:item1], @"file1.txt");
  XCTAssertFalse([dataSource outlineView:outlineView isItemExpandable:item1]);
  XCTAssertEqual([dataSource changeForItem:item1], XitChangeAdded);
}

@end
