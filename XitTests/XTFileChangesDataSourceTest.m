#import "XTTest.h"
#include "XTQueueUtils.h"
#import "Xit-Swift.h"

@interface XTFileChangesDataSourceTest : XTTest

@end

@implementation XTFileChangesDataSourceTest

- (void)testInitialCommit
{
  XTWindowController *winController = [[XTWindowController alloc] init];
  XTFileChangesDataSource *dataSource = [[XTFileChangesDataSource alloc] init];
  NSOutlineView *outlineView = [[NSOutlineView alloc] init];

  winController.selectedModel = [[XTCommitChanges alloc]
      initWithRepository:self.repository sha:self.repository.headSHA];
  dataSource.repository = self.repository;
  dataSource.repoController = (XTWindowController*)winController;
  outlineView.dataSource = dataSource;
  [dataSource reload];
  [self waitForRepoQueue];
  WaitForQueue(dispatch_get_main_queue());

  XCTAssertEqual(
      [dataSource outlineView:outlineView numberOfChildrenOfItem:nil], 1L);

  id item1 = [dataSource outlineView:outlineView child:0 ofItem:nil];

  XCTAssertEqualObjects([dataSource pathFor:item1], @"file1.txt");
  XCTAssertFalse([dataSource outlineView:outlineView isItemExpandable:item1]);
  XCTAssertEqual([dataSource changeFor:item1], XitChangeAdded);
}

@end
