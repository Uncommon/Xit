#import "XTTest.h"
#import "XTTest.h"
#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import "XTSideBarItem.h"
#import "XTSideBarDataSource.h"
#import "XTHistoryItem.h"

@interface XTSideBarDataSorceTests : XTTest

@end

@interface MockTextField : NSObject {
 @private
  NSString *stringValue;
}
@property(strong) NSString *stringValue;
@end

@interface MockCellView : NSObject {
 @private
  MockTextField *textField;
}
@property(readonly) MockTextField *textField;
@end

@interface MockSidebarOutlineView : NSObject {
}
- (id)makeViewWithIdentifier:(NSString *)identifier owner:(id)owner;
- (id)parentForItem:(id)item;
@end

@implementation XTSideBarDataSorceTests

- (void)testXTSideBarDataSourceReload
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

- (void)testXTSideBarDataSourceStashes
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

- (void)testXTSideBarDataSourceReomtes
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

  [remoteRepository executeGitWithArgs:configArgs error:&error];
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

- (void)testXTSideBarDataSourceBranchesAndTags
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
  STAssertTrue((nr == 4), @"found %d roots FAIL", nr);

  // TAGS
  id tags = [sbds outlineView:nil child:XTTagsGroupIndex ofItem:nil];
  STAssertTrue((tags != nil), @"no tags");

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
