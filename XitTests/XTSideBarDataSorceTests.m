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
  NSOutlineView *outlineView;
  XTSideBarDataSource *sbds;
}

- (id)groupItemForIndex:(NSUInteger)index;

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

- (void)setUp
{
  [super setUp];
  sbds = [[XTSideBarDataSource alloc] init];
  outlineView = [[NSOutlineView alloc] init];
}

- (id)groupItemForIndex:(NSUInteger)index
{
  // Add one to skip the staging item
  return [sbds outlineView:outlineView child:index+1 ofItem:nil];
}

- (void)testReload
{
  [sbds setRepo:self.repository];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(repoChanged:)
                                               name:XTRepositoryChangedNotification
                                             object:self.repository];

  if (![self.repository createBranch:@"b1"])
    XCTFail(@"Create Branch 'b1'");

  NSArray *titles, *expectedTitles = @[ @"b1", @"master" ];

  // Sometimes it reloads too soon, so give it a few tries.
  for (int i = 0; i < 5; ++i) {
    runLoop = CFRunLoopGetCurrent();
    if (!CFRunLoopRunWithTimeout(5))
      NSLog(@"warning: TimeOut on reload");
    runLoop = NULL;

    id branches = [self groupItemForIndex:XTBranchesGroupIndex];

    titles = [[branches children] valueForKey:@"title"];
    if ([titles isEqual:expectedTitles])
      break;
  }
  XCTAssertEqualObjects(titles, expectedTitles);

  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)repoChanged:(NSNotification*)note
{
  if (runLoop != NULL)
    CFRunLoopStop(runLoop);
}

- (void)testStashes
{
  XCTAssertTrue([self writeTextToFile1:@"second text"], @"");
  XCTAssertTrue([self.repository saveStash:@"s1"], @"");
  XCTAssertTrue([self writeTextToFile1:@"third text"], @"");
  XCTAssertTrue([self.repository saveStash:@"s2"], @"");

  [sbds setRepo:self.repository];
  [sbds reload];
  [self waitForRepoQueue];

  id stashes = [self groupItemForIndex:XTStashesGroupIndex];
  XCTAssertNotNil(stashes);

  NSInteger stashCount = [sbds outlineView:outlineView numberOfChildrenOfItem:stashes];
  XCTAssertEqual(stashCount, 2L, @"");
}

- (void)testRemotes
{
  [self makeRemoteRepo];

  if (![self.repository checkout:@"master" error:NULL]) {
    XCTFail(@"checkout master");
  }

  if (![self.repository createBranch:@"b1"]) {
    XCTFail(@"Create Branch 'b1'");
  }

  if (![self.repository addRemote:@"origin" withUrl:self.remoteRepoPath]) {
    XCTFail(@"add origin '%@'", self.remoteRepoPath);
  }

  NSError *error = nil;
  NSArray *configArgs = @[ @"config", @"receive.denyCurrentBranch", @"ignore" ];

  [self.remoteRepository executeGitWithArgs:configArgs writes:NO error:&error];
  if (error != nil) {
    XCTFail(@"Ignore denyCurrentBranch");
    return;
  }

  if (![self.repository push:@"origin"]) {
    XCTFail(@"push origin");
    return;
  }

  MockSidebarOutlineView *sov = [[MockSidebarOutlineView alloc] init];
  
  [sbds setRepo:self.repository];
  [sbds reload];
  [self waitForRepoQueue];

  id remotes = [self groupItemForIndex:XTRemotesGroupIndex];
  XCTAssertTrue((remotes != nil), @"no remotes");

  NSInteger nr = [sbds outlineView:outlineView numberOfChildrenOfItem:remotes];
  XCTAssertTrue((nr == 1), @"found %ld remotes FAIL", (long)nr);

  // BRANCHES
  id remote = [sbds outlineView:outlineView child:0 ofItem:remotes];
  NSTableCellView *remoteView =
      (NSTableCellView *)[sbds outlineView:(NSOutlineView *)sov
                        viewForTableColumn:nil
                                      item:remote];
  NSString *rName = remoteView.textField.stringValue;
  XCTAssertTrue([rName isEqualToString:@"origin"], @"found remote '%@'", rName);

  NSInteger nb = [sbds outlineView:outlineView numberOfChildrenOfItem:remote];
  XCTAssertTrue((nb == 2), @"found %ld branches FAIL", (long)nb);

  bool branchB1Found = false;
  bool branchMasterFound = false;
  
  for (int n = 0; n < nb; n++) {
    id branch = [sbds outlineView:outlineView child:n ofItem:remote];
    BOOL isExpandable = [sbds outlineView:outlineView isItemExpandable:branch];
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
  if (![self.repository createBranch:@"b1"]) {
    XCTFail(@"Create Branch 'b1'");
  }

  if (![self.repository createTag:@"t1" withMessage:@"msg"]) {
    XCTFail(@"Create Tag 't1'");
  }

  MockSidebarOutlineView *sov = [[MockSidebarOutlineView alloc] init];
  [sbds setRepo:self.repository];
  [sbds reload];
  [self waitForRepoQueue];

  NSInteger nr = [sbds outlineView:outlineView numberOfChildrenOfItem:nil];
  XCTAssertEqual(nr, 6L);

  // TAGS
  id tags = [self groupItemForIndex:XTTagsGroupIndex];
  XCTAssertNotNil(tags);

  NSInteger nt = [sbds outlineView:outlineView numberOfChildrenOfItem:tags];
  XCTAssertTrue((nt == 1), @"found %ld tags FAIL", (long)nt);

  bool tagT1Found = false;
  for (int n = 0; n < nt; n++) {
    XTSideBarItem *tag = [sbds outlineView:outlineView child:n ofItem:tags];
    XCTAssertTrue(tag.sha != Nil, @"Tag '%@' must have sha", tag.title);

    BOOL isExpandable = [sbds outlineView:outlineView isItemExpandable:tag];
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
  id branches = [self groupItemForIndex:XTBranchesGroupIndex];
  XCTAssertTrue((branches != nil), @"no branches FAIL");

  NSInteger nb = [sbds outlineView:outlineView numberOfChildrenOfItem:branches];
  XCTAssertTrue((nb == 2), @"found %ld branches FAIL", (long)nb);

  bool branchB1Found = false;
  bool branchMasterFound = false;
  for (int n = 0; n < nb; n++) {
    XTSideBarItem *branch = [sbds outlineView:outlineView child:n ofItem:branches];
    XCTAssertTrue(branch.sha != Nil, @"Branch '%@' must have sha", branch.title);

    BOOL isExpandable = [sbds outlineView:outlineView isItemExpandable:branch];
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

  XCTAssertTrue([self.repository addSubmoduleAtPath:@"sub1"
                                          urlOrPath:@"../repo1"
                                              error:NULL]);
  XCTAssertTrue([self.repository addSubmoduleAtPath:@"sub2"
                                          urlOrPath:@"../repo2"
                                              error:NULL]);

  [sbds setRepo:self.repository];
  [sbds reload];
  [self waitForRepoQueue];

  id subs = [self groupItemForIndex:XTSubmodulesGroupIndex];
  XCTAssertNotNil(subs);

  const NSInteger subCount = [sbds outlineView:outlineView numberOfChildrenOfItem:subs];
  XCTAssertEqual(subCount, 2L);

  for (int i = 0; i < subCount; ++i) {
    XTSubmoduleItem *sub = [sbds outlineView:outlineView child:i ofItem:subs];
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
  if (![self.repository createBranch:@"b1"]) {
    XCTFail(@"Create Branch 'b1'");
  }

  [sbds setRepo:self.repository];
  [sbds reload];

  // Start at 1 to skip "Staging"
  for (NSInteger i = 1; i < [sbds outlineView:outlineView numberOfChildrenOfItem:nil];
       ++i) {
    id root = [sbds outlineView:outlineView child:i ofItem:nil];
    XCTAssertTrue([sbds outlineView:outlineView isGroupItem:root],
                 @"item %ld should be group", (long)i);
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
