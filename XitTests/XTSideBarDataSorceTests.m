#import "XTTest.h"
#import "XTTest.h"
#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import "XTSideBarItem.h"
#import "XTSideBarDataSource.h"
#import "XTSubmoduleItem.h"
#import "XTHistoryItem.h"
#include "CFRunLoop+Extensions.h"
#import <ObjectiveGit/ObjectiveGit.h>

@interface XTSideBarDataSorceTests : XTTest
{
  CFRunLoopRef runLoop;
}

@end

@interface MockTextField : NSObject
@property(strong) NSString *stringValue;
@end

@interface MockCellView : NSObject
@property(readonly) MockTextField *textField;
@end

@interface MockSidebarOutlineView : NSObject
- (id)makeViewWithIdentifier:(NSString *)identifier owner:(id)owner;
- (id)parentForItem:(id)item;
@end

@implementation XTSideBarDataSorceTests

- (void)testReload
{
  XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];

  [sbds setRepo:repository];
  [sbds addObserver:self forKeyPath:@"reload" options:0 context:nil];

  [repository start];

  if (![repository createBranch:@"b1"])
    XCTFail(@"Create Branch 'b1'");

  NSArray *titles, *expectedTitles = @[ @"b1", @"master" ];

  // Sometimes it reloads too soon, so give it a few tries.
  for (int i = 0; i < 5; ++i) {
    runLoop = CFRunLoopGetCurrent();
    if (!CFRunLoopRunWithTimeout(10))
      XCTFail(@"TimeOut on reload");
    runLoop = NULL;

    id branches = [sbds outlineView:nil child:XTBranchesGroupIndex ofItem:nil];

    titles = [[branches children] valueForKey:@"title"];
    if ([titles isEqual:expectedTitles])
      break;
  }
  XCTAssertEqualObjects(titles, expectedTitles);

  [sbds removeObserver:self forKeyPath:@"reload"];
  [repository stop];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if ([keyPath isEqualToString:@"reload"] && (runLoop != NULL))
    CFRunLoopStop(runLoop);
}

- (void)testStashes
{
  XCTAssertTrue([self writeTextToFile1:@"second text"], @"");
  XCTAssertTrue([repository saveStash:@"s1"], @"");
  XCTAssertTrue([self writeTextToFile1:@"third text"], @"");
  XCTAssertTrue([repository saveStash:@"s2"], @"");

  XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];
  [sbds setRepo:repository];
  [sbds reload];
  [self waitForRepoQueue];

  id stashes = [sbds outlineView:nil child:XTStashesGroupIndex ofItem:nil];
  XCTAssertTrue((stashes != nil), @"no stashes");

  NSInteger stashCount = [sbds outlineView:nil numberOfChildrenOfItem:stashes];
  XCTAssertEqual(stashCount, 2L, @"");
}

- (void)testRemotes
{
  [self makeRemoteRepo];

  if (![repository checkout:@"master" error:NULL]) {
    XCTFail(@"checkout master");
  }

  if (![repository createBranch:@"b1"]) {
    XCTFail(@"Create Branch 'b1'");
  }

  if (![repository addRemote:@"origin" withUrl:remoteRepoPath]) {
    XCTFail(@"add origin '%@'", remoteRepoPath);
  }

  NSError *error = nil;
  NSArray *configArgs = @[ @"config", @"receive.denyCurrentBranch", @"ignore" ];

  [remoteRepository executeGitWithArgs:configArgs writes:NO error:&error];
  if (error != nil) {
    XCTFail(@"Ignore denyCurrentBranch");
    return;
  }

  if (![repository push:@"origin"]) {
    XCTFail(@"push origin");
    return;
  }

  MockSidebarOutlineView *sov = [[MockSidebarOutlineView alloc] init];
  XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];
  [sbds setRepo:repository];
  [sbds reload];
  [self waitForRepoQueue];

  id remotes = [sbds outlineView:nil child:XTRemotesGroupIndex ofItem:nil];
  XCTAssertTrue((remotes != nil), @"no remotes");

  NSInteger nr = [sbds outlineView:nil numberOfChildrenOfItem:remotes];
  XCTAssertTrue((nr == 1), @"found %d remotes FAIL", nr);

  // BRANCHES
  id remote = [sbds outlineView:nil child:0 ofItem:remotes];
  NSTableCellView *remoteView =
      (NSTableCellView *)[sbds outlineView:(NSOutlineView *)sov
                        viewForTableColumn:nil
                                      item:remote];
  NSString *rName = remoteView.textField.stringValue;
  XCTAssertTrue([rName isEqualToString:@"origin"], @"found remote '%@'", rName);

  NSInteger nb = [sbds outlineView:nil numberOfChildrenOfItem:remote];
  XCTAssertTrue((nb == 2), @"found %d branches FAIL", nb);

  bool branchB1Found = false;
  bool branchMasterFound = false;
  for (int n = 0; n < nb; n++) {
    id branch = [sbds outlineView:nil child:n ofItem:remote];
    BOOL isExpandable = [sbds outlineView:nil isItemExpandable:branch];
    XCTAssertTrue(isExpandable == NO, @"Branches must be no Expandable");

    NSTableCellView *branchView =
        (NSTableCellView *)[sbds outlineView:(NSOutlineView *)sov
                          viewForTableColumn:nil
                                        item:branch];
    NSString *bName = branchView.textField.stringValue;
    if ([bName isEqualToString:@"master"]) {
      branchMasterFound = YES;
    } else if ([bName isEqualToString:@"b1"]) {
      branchB1Found = YES;
    }
  }
  XCTAssertTrue(branchMasterFound, @"Branch 'master' Not found");
  XCTAssertTrue(branchB1Found, @"Branch 'b1' Not found");
}

- (void)testBranchesAndTags
{
  if (![repository createBranch:@"b1"]) {
    XCTFail(@"Create Branch 'b1'");
  }

  if (![repository createTag:@"t1" withMessage:@"msg"]) {
    XCTFail(@"Create Tag 't1'");
  }

  MockSidebarOutlineView *sov = [[MockSidebarOutlineView alloc] init];
  XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];
  [sbds setRepo:repository];
  [sbds reload];
  [self waitForRepoQueue];

  NSInteger nr = [sbds outlineView:nil numberOfChildrenOfItem:nil];
  XCTAssertTrue((nr == 5), @"found %d roots FAIL", nr);

  // TAGS
  id tags = [sbds outlineView:nil child:XTTagsGroupIndex ofItem:nil];
  XCTAssertNotNil(tags);

  NSInteger nt = [sbds outlineView:nil numberOfChildrenOfItem:tags];
  XCTAssertTrue((nt == 1), @"found %d tags FAIL", nt);

  bool tagT1Found = false;
  for (int n = 0; n < nt; n++) {
    XTSideBarItem *tag = [sbds outlineView:nil child:n ofItem:tags];
    XCTAssertTrue(tag.sha != Nil, @"Tag '%@' must have sha", tag.title);

    BOOL isExpandable = [sbds outlineView:nil isItemExpandable:tag];
    XCTAssertTrue(isExpandable == NO, @"Tags must be no Expandable");

    NSTableCellView *view =
        (NSTableCellView *)[sbds outlineView:(NSOutlineView *)sov
                          viewForTableColumn:nil
                                        item:tag];
    if ([view.textField.stringValue isEqualToString:@"t1"]) {
      tagT1Found = YES;
    }
  }
  XCTAssertTrue(tagT1Found, @"Tag 't1' Not found");

  // BRANCHES
  id branches = [sbds outlineView:nil child:XTBranchesGroupIndex ofItem:nil];
  XCTAssertTrue((branches != nil), @"no branches FAIL");

  NSInteger nb = [sbds outlineView:nil numberOfChildrenOfItem:branches];
  XCTAssertTrue((nb == 2), @"found %d branches FAIL", nb);

  bool branchB1Found = false;
  bool branchMasterFound = false;
  for (int n = 0; n < nb; n++) {
    XTSideBarItem *branch = [sbds outlineView:nil child:n ofItem:branches];
    XCTAssertTrue(branch.sha != Nil, @"Branch '%@' must have sha", branch.title);

    BOOL isExpandable = [sbds outlineView:nil isItemExpandable:branch];
    XCTAssertTrue(isExpandable == NO, @"Branches must be no Expandable");

    NSTableCellView *branchView =
        (NSTableCellView *)[sbds outlineView:(NSOutlineView *)sov
                          viewForTableColumn:nil
                                        item:branch];
    NSString *bName = branchView.textField.stringValue;
    if ([bName isEqualToString:@"master"]) {
      branchMasterFound = YES;
    } else if ([bName isEqualToString:@"b1"]) {
      branchB1Found = YES;
    }
  }
  XCTAssertTrue(branchMasterFound, @"Branch 'master' Not found");
  XCTAssertTrue(branchB1Found, @"Branch 'b1' Not found");
}

- (void)testSubmodules
{
  NSString *tempPath = NSTemporaryDirectory();
  XTRepository *repo1 = [self createRepo:
      [tempPath stringByAppendingPathComponent:@"repo1"]];
  XTRepository *repo2 = [self createRepo:
      [tempPath stringByAppendingPathComponent:@"repo2"]];
  XCTAssertNotNil(repo1, @"");
  XCTAssertNotNil(repo2, @"");

  XCTAssertTrue([self commitNewTextFile:@"file1"
                               content:@"blah"
                          inRepository:repo1]);
  XCTAssertTrue([self commitNewTextFile:@"file2"
                               content:@"fffff"
                          inRepository:repo2]);

  XCTAssertTrue([repository addSubmoduleAtPath:@"sub1"
                                    urlOrPath:@"../repo1"
                                        error:NULL]);
  XCTAssertTrue([repository addSubmoduleAtPath:@"sub2"
                                    urlOrPath:@"../repo2"
                                        error:NULL]);

  XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];
  [sbds setRepo:repository];
  [sbds reload];
  [self waitForRepoQueue];

  id subs = [sbds outlineView:nil child:XTSubmodulesGroupIndex ofItem:nil];
  XCTAssertNotNil(subs);

  const NSInteger subCount = [sbds outlineView:nil numberOfChildrenOfItem:subs];
  XCTAssertEqual(subCount, 2L);

  for (int i = 0; i < subCount; ++i) {
    XTSubmoduleItem *sub = [sbds outlineView:nil child:i ofItem:subs];
    NSString *name = [NSString stringWithFormat:@"sub%d", i+1];
    NSString *url = [NSString stringWithFormat:@"../repo%d", i+1];

    XCTAssertTrue([sub isKindOfClass:[XTSubmoduleItem class]]);
    XCTAssertNotNil(sub.submodule);
    XCTAssertEqualObjects(sub.submodule.name, name, @"");
    XCTAssertEqualObjects(sub.submodule.URLString, url);
  }
}

- (void)testGroupItems
{
  if (![repository createBranch:@"b1"]) {
    XCTFail(@"Create Branch 'b1'");
  }

  XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];
  [sbds setRepo:repository];
  [sbds reload];

  for (NSInteger i = 0; i < [sbds outlineView:nil numberOfChildrenOfItem:nil];
       ++i) {
    id root = [sbds outlineView:nil child:i ofItem:nil];
    XCTAssertTrue([sbds outlineView:nil isGroupItem:root],
                 @"item %d should be group", i);
  }
}

@end


@implementation MockTextField

@synthesize stringValue;

- (void)setFormatter:(id)formatter {}
- (void)setTarget:(id)target {}
- (void)setAction:(SEL)action {}
- (void)setEditable:(BOOL)editable {}
- (void)setSelectable:(BOOL)selectable {}

@end


@implementation MockCellView

@synthesize textField;

- (id)init
{
  if ([super init] == nil)
    return nil;
  textField = [[MockTextField alloc] init];
  return self;
}

- (id)imageView
{
  return nil;
}

- (id)button
{
  return nil;
}

- (void)setItem:(id)item
{
}

@end


@implementation MockSidebarOutlineView

- (id)makeViewWithIdentifier:(NSString *)identifier owner:(id)owner
{
  return [[MockCellView alloc] init];
}

- (id)parentForItem:(id)item
{
  return nil;
}

@end
