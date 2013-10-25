#import "XTTest.h"
#import "XTTest.h"
#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import "XTSideBarItem.h"
#import "XTSideBarDataSource.h"
#import "XTSubmoduleItem.h"
#import "XTHistoryItem.h"
#import <ObjectiveGit/ObjectiveGit.h>

@interface XTSideBarDataSorceTests : XTTest

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

  reloadDetected = NO;
  if (![repository createBranch:@"b1"]) {
    STFail(@"Create Branch 'b1'");
  }

  int timeOut = 0;
  while (!reloadDetected && (++timeOut <= 10)) {
    [[NSRunLoop currentRunLoop]
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    NSLog(@"Polling... (%d)", timeOut);
  }
  if (timeOut > 10) {
    STFail(@"TimeOut on reload");
  }

  id branches = [sbds outlineView:nil child:XTBranchesGroupIndex ofItem:nil];
  NSInteger nb = [sbds outlineView:nil numberOfChildrenOfItem:branches];
  STAssertTrue((nb == 2), @"found %d branches FAIL", nb);

  [sbds removeObserver:self forKeyPath:@"reload"];
  [repository stop];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if ([keyPath isEqualToString:@"reload"]) {
    reloadDetected = YES;
  }
}

- (void)testStashes
{
  STAssertTrue([self writeTextToFile1:@"second text"], @"");
  STAssertTrue([repository saveStash:@"s1"], @"");
  STAssertTrue([self writeTextToFile1:@"third text"], @"");
  STAssertTrue([repository saveStash:@"s2"], @"");

  XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];
  [sbds setRepo:repository];
  [sbds reload];
  [self waitForRepoQueue];

  id stashes = [sbds outlineView:nil child:XTStashesGroupIndex ofItem:nil];
  STAssertTrue((stashes != nil), @"no stashes");

  NSInteger stashCount = [sbds outlineView:nil numberOfChildrenOfItem:stashes];
  STAssertEquals(stashCount, 2L, @"");
}

- (void)testRemotes
{
  [self makeRemoteRepo];

  if (![repository checkout:@"master" error:NULL]) {
    STFail(@"checkout master");
  }

  if (![repository createBranch:@"b1"]) {
    STFail(@"Create Branch 'b1'");
  }

  if (![repository addRemote:@"origin" withUrl:remoteRepoPath]) {
    STFail(@"add origin '%@'", remoteRepoPath);
  }

  NSError *error = nil;
  NSArray *configArgs = @[ @"config", @"receive.denyCurrentBranch", @"ignore" ];

  [remoteRepository executeGitWithArgs:configArgs writes:NO error:&error];
  if (error != nil) {
    STFail(@"Ignore denyCurrentBranch");
    return;
  }

  if (![repository push:@"origin"]) {
    STFail(@"push origin");
    return;
  }

  MockSidebarOutlineView *sov = [[MockSidebarOutlineView alloc] init];
  XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];
  [sbds setRepo:repository];
  [sbds reload];
  [self waitForRepoQueue];

  id remotes = [sbds outlineView:nil child:XTRemotesGroupIndex ofItem:nil];
  STAssertTrue((remotes != nil), @"no remotes");

  NSInteger nr = [sbds outlineView:nil numberOfChildrenOfItem:remotes];
  STAssertTrue((nr == 1), @"found %d remotes FAIL", nr);

  // BRANCHES
  id remote = [sbds outlineView:nil child:0 ofItem:remotes];
  NSTableCellView *remoteView =
      (NSTableCellView *)[sbds outlineView:(NSOutlineView *)sov
                        viewForTableColumn:nil
                                      item:remote];
  NSString *rName = remoteView.textField.stringValue;
  STAssertTrue([rName isEqualToString:@"origin"], @"found remote '%@'", rName);

  NSInteger nb = [sbds outlineView:nil numberOfChildrenOfItem:remote];
  STAssertTrue((nb == 2), @"found %d branches FAIL", nb);

  bool branchB1Found = false;
  bool branchMasterFound = false;
  for (int n = 0; n < nb; n++) {
    id branch = [sbds outlineView:nil child:n ofItem:remote];
    BOOL isExpandable = [sbds outlineView:nil isItemExpandable:branch];
    STAssertTrue(isExpandable == NO, @"Branches must be no Expandable");

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
  STAssertTrue(branchMasterFound, @"Branch 'master' Not found");
  STAssertTrue(branchB1Found, @"Branch 'b1' Not found");
}

- (void)testBranchesAndTags
{
  if (![repository createBranch:@"b1"]) {
    STFail(@"Create Branch 'b1'");
  }

  if (![repository createTag:@"t1" withMessage:@"msg"]) {
    STFail(@"Create Tag 't1'");
  }

  MockSidebarOutlineView *sov = [[MockSidebarOutlineView alloc] init];
  XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];
  [sbds setRepo:repository];
  [sbds reload];
  [self waitForRepoQueue];

  NSInteger nr = [sbds outlineView:nil numberOfChildrenOfItem:nil];
  STAssertTrue((nr == 5), @"found %d roots FAIL", nr);

  // TAGS
  id tags = [sbds outlineView:nil child:XTTagsGroupIndex ofItem:nil];
  STAssertNotNil(tags, nil);

  NSInteger nt = [sbds outlineView:nil numberOfChildrenOfItem:tags];
  STAssertTrue((nt == 1), @"found %d tags FAIL", nt);

  bool tagT1Found = false;
  for (int n = 0; n < nt; n++) {
    XTSideBarItem *tag = [sbds outlineView:nil child:n ofItem:tags];
    STAssertTrue(tag.sha != Nil, @"Tag '%@' must have sha", tag.title);

    BOOL isExpandable = [sbds outlineView:nil isItemExpandable:tag];
    STAssertTrue(isExpandable == NO, @"Tags must be no Expandable");

    NSTableCellView *view =
        (NSTableCellView *)[sbds outlineView:(NSOutlineView *)sov
                          viewForTableColumn:nil
                                        item:tag];
    if ([view.textField.stringValue isEqualToString:@"t1"]) {
      tagT1Found = YES;
    }
  }
  STAssertTrue(tagT1Found, @"Tag 't1' Not found");

  // BRANCHES
  id branches = [sbds outlineView:nil child:XTBranchesGroupIndex ofItem:nil];
  STAssertTrue((branches != nil), @"no branches FAIL");

  NSInteger nb = [sbds outlineView:nil numberOfChildrenOfItem:branches];
  STAssertTrue((nb == 2), @"found %d branches FAIL", nb);

  bool branchB1Found = false;
  bool branchMasterFound = false;
  for (int n = 0; n < nb; n++) {
    XTSideBarItem *branch = [sbds outlineView:nil child:n ofItem:branches];
    STAssertTrue(branch.sha != Nil, @"Branch '%@' must have sha", branch.title);

    BOOL isExpandable = [sbds outlineView:nil isItemExpandable:branch];
    STAssertTrue(isExpandable == NO, @"Branches must be no Expandable");

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
  STAssertTrue(branchMasterFound, @"Branch 'master' Not found");
  STAssertTrue(branchB1Found, @"Branch 'b1' Not found");
}

- (void)testSubmodules
{
  NSString *tempPath = NSTemporaryDirectory();
  XTRepository *repo1 = [self createRepo:
      [tempPath stringByAppendingPathComponent:@"repo1"]];
  XTRepository *repo2 = [self createRepo:
      [tempPath stringByAppendingPathComponent:@"repo2"]];
  STAssertNotNil(repo1, @"");
  STAssertNotNil(repo2, @"");

  STAssertTrue([self commitNewTextFile:@"file1"
                               content:@"blah"
                          inRepository:repo1], nil);
  STAssertTrue([self commitNewTextFile:@"file2"
                               content:@"fffff"
                          inRepository:repo2], nil);

  STAssertTrue([repository addSubmoduleAtPath:@"sub1"
                                    urlOrPath:@"../repo1"
                                        error:NULL], nil);
  STAssertTrue([repository addSubmoduleAtPath:@"sub2"
                                    urlOrPath:@"../repo2"
                                        error:NULL], nil);

  XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];
  [sbds setRepo:repository];
  [sbds reload];
  [self waitForRepoQueue];

  id subs = [sbds outlineView:nil child:XTSubmodulesGroupIndex ofItem:nil];
  STAssertNotNil(subs, nil);

  const NSInteger subCount = [sbds outlineView:nil numberOfChildrenOfItem:subs];
  STAssertEquals(subCount, 2L, nil);

  for (int i = 0; i < subCount; ++i) {
    XTSubmoduleItem *sub = [sbds outlineView:nil child:i ofItem:subs];
    NSString *name = [NSString stringWithFormat:@"sub%d", i+1];
    NSString *url = [NSString stringWithFormat:@"../repo%d", i+1];

    STAssertTrue([sub isKindOfClass:[XTSubmoduleItem class]], nil);
    STAssertNotNil(sub.submodule, nil);
    STAssertEqualObjects(sub.submodule.name, name, @"");
    STAssertEqualObjects(sub.submodule.URLString, url, nil);
  }
}

- (void)testGroupItems
{
  if (![repository createBranch:@"b1"]) {
    STFail(@"Create Branch 'b1'");
  }

  XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];
  [sbds setRepo:repository];
  [sbds reload];

  for (NSInteger i = 0; i < [sbds outlineView:nil numberOfChildrenOfItem:nil];
       ++i) {
    id root = [sbds outlineView:nil child:i ofItem:nil];
    STAssertTrue([sbds outlineView:nil isGroupItem:root],
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
