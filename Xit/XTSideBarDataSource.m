#import "XTSideBarDataSource.h"
#import "XTConstants.h"
#import "XTDocController.h"
#import "XTSideBarItem.h"
#import "XTSubmoduleItem.h"
#import "XTRefFormatter.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTRemoteItem.h"
#import "XTRemoteBranchItem.h"
#import "XTTagItem.h"
#import "XTRemotesItem.h"
#import "XTSideBarTableCellView.h"
#import "NSMutableDictionary+MultiObjectForKey.h"
#import <ObjectiveGit/ObjectiveGit.h>

NSString * const XTStagingSHA = @"";

@interface XTSideBarDataSource ()
- (NSArray *)loadRoots;
@end

@implementation XTSideBarDataSource


- (id)init
{
  if ((self = [super init]) != nil) {
    _roots = [self makeRoots];
    _stagingItem = [[XTSideBarItem alloc] initWithTitle:@"Staging"
                                                 andSha:XTStagingSHA];
  }

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray *)makeRoots
{
  XTSideBarItem *branches = [[XTSideBarItem alloc] initWithTitle:@"BRANCHES"];
  XTRemotesItem *remotes = [[XTRemotesItem alloc] initWithTitle:@"REMOTES"];
  XTSideBarItem *tags = [[XTSideBarItem alloc] initWithTitle:@"TAGS"];
  XTSideBarItem *stashes = [[XTSideBarItem alloc] initWithTitle:@"STASHES"];
  XTSideBarItem *subs = [[XTSideBarItem alloc] initWithTitle:@"SUBMODULES"];

  return @[ branches, remotes, tags, stashes, subs ];
}

- (void)awakeFromNib
{
  [_outline setTarget:self];
  [_outline setDoubleAction:@selector(doubleClick:)];
}

- (void)setRepo:(XTRepository *)newRepo
{
  _repo = newRepo;
  if (_repo != nil) {
    [_repo addReloadObserver:self selector:@selector(repoChanged:)];
    [self reload];
  }
}

- (void)repoChanged:(NSNotification *)note
{
  NSArray *paths = [note userInfo][XTPathsKey];

  for (NSString *path in paths) {
    if ([path hasPrefix:@".git/refs/"]) {
      [self reload];
      break;
    }
  }
  [_outline performSelectorOnMainThread:@selector(reloadData)
                             withObject:nil
                          waitUntilDone:NO];
}

- (void)reload
{
  [_repo executeOffMainThread:^{
    NSArray *newRoots = [self loadRoots];

    dispatch_async(dispatch_get_main_queue(), ^{
      [self willChangeValueForKey:@"reload"];
      _roots = newRoots;
      [self didChangeValueForKey:@"reload"];
      [_outline reloadData];
      // Empty groups get automatically collapsed, so counter that.
      [_outline expandItem:nil expandChildren:YES];
    });
  }];
}

- (NSArray *)loadRoots
{
  NSMutableDictionary *refsIndex = [NSMutableDictionary dictionary];
  NSMutableArray *branches = [NSMutableArray array];
  NSMutableArray *tags = [NSMutableArray array];
  NSMutableArray *remotes = [NSMutableArray array];
  NSMutableArray *stashes = [NSMutableArray array];
  NSMutableArray *submodules = [NSMutableArray array];

  [self loadBranches:branches tags:tags remotes:remotes refsIndex:refsIndex];
  [self loadStashes:stashes refsIndex:refsIndex];
  [_repo readSubmodulesWithBlock:^(GTSubmodule *sub) {
    [submodules addObject:[[XTSubmoduleItem alloc] initWithSubmodule:sub]];
  }];

  NSArray *newRoots = [self makeRoots];

  [newRoots[XTBranchesGroupIndex] setChildren:branches];
  [newRoots[XTTagsGroupIndex] setChildren:tags];
  [newRoots[XTRemotesGroupIndex] setChildren:remotes];
  [newRoots[XTStashesGroupIndex] setChildren:stashes];
  [newRoots[XTSubmodulesGroupIndex] setChildren:submodules];

  _repo.refsIndex = refsIndex;
  _currentBranch = [_repo currentBranch];

  return newRoots;
}

- (void)loadStashes:(NSMutableArray *)stashes
          refsIndex:(NSMutableDictionary *)refsIndex
{
  [_repo readStashesWithBlock:^(NSString *commit, NSString *name) {
    XTSideBarItem *stash = [[XTStashItem alloc] initWithTitle:name];
    [stashes addObject:stash];
    [refsIndex addObject:name forKey:commit];
  }];
}

- (void)loadBranches:(NSMutableArray *)branches
                tags:(NSMutableArray *)tags
             remotes:(NSMutableArray *)remotes
           refsIndex:(NSMutableDictionary *)refsIndex
{
  NSMutableDictionary *remoteIndex = [NSMutableDictionary dictionary];
  NSMutableDictionary *tagIndex = [NSMutableDictionary dictionary];

  void (^localBlock)(NSString *, NSString *) =
      ^(NSString *name, NSString *commit) {
    XTLocalBranchItem *branch =
        [[XTLocalBranchItem alloc] initWithTitle:[name lastPathComponent]
                                          andSha:commit];

    [branches addObject:branch];
    [refsIndex addObject:[@"refs/heads" stringByAppendingPathComponent:name]
                  forKey:branch.sha];
  };

  void (^remoteBlock)(NSString *, NSString *, NSString *) =
      ^(NSString *remoteName, NSString *branchName, NSString *commit) {
    XTSideBarItem *remote = remoteIndex[remoteName];

    if (remote == nil) {
      remote = [[XTRemoteItem alloc] initWithTitle:remoteName];
      [remotes addObject:remote];
      remoteIndex[remoteName] = remote;
    }

    XTRemoteBranchItem *branch =
        [[XTRemoteBranchItem alloc] initWithTitle:branchName
                                           remote:remoteName
                                              sha:commit];
    NSString *branchRef =
        [NSString stringWithFormat:@"refs/remotes/%@/%@", remoteName, branchName];

    [remote addchild:branch];
    [refsIndex addObject:branchRef
                  forKey:branch.sha];
  };

  void (^tagBlock)(NSString *, NSString *) = ^(NSString *name, NSString *commit) {
    XTTagItem *tag;

    if ([name hasSuffix:@"^{}"]) {
      name = [name substringToIndex:name.length - 3];
      tag = tagIndex[name];
      tag.sha = commit;
    } else {
      tag = [[XTTagItem alloc] initWithTitle:name andSha:commit];
      [tags addObject:tag];
      tagIndex[name] = tag;
    }
    [refsIndex addObject:[@"refs/tags" stringByAppendingPathComponent:name]
                  forKey:tag.sha];
  };

  [_repo readRefsWithLocalBlock:localBlock
                    remoteBlock:remoteBlock
                       tagBlock:tagBlock];
}

- (void)doubleClick:(id)sender
{
  id clickedItem = [_outline itemAtRow:[_outline clickedRow]];

  if ([clickedItem isKindOfClass:[XTSubmoduleItem class]]) {
    XTSubmoduleItem *subItem = (XTSubmoduleItem*)clickedItem;
    NSString *subPath = subItem.submodule.path;
    NSString *rootPath = _repo.repoURL.path;
    NSURL *subURL = [NSURL fileURLWithPath:
        [rootPath stringByAppendingPathComponent:subPath]];
    
    [[NSDocumentController sharedDocumentController]
        openDocumentWithContentsOfURL:subURL
                              display:YES
                    completionHandler:^(NSDocument *doc,BOOL open, NSError *error) {}];
    // TODO: zoom effect
    // http://github.com/MrNoodle/NoodleKit/blob/master/NSWindow-NoodleEffects.m
  }
}

- (XTLocalBranchItem *)itemForBranchName:(NSString *)branch
{
  XTSideBarItem *branches = _roots[XTBranchesGroupIndex];

  for (NSInteger i = 0; i < [branches numberOfChildren]; ++i) {
    XTLocalBranchItem *branchItem = [branches childAtIndex:i];

    if ([branchItem.title isEqual:branch])
      return branchItem;
  }
  return nil;
}

- (XTSideBarItem *)itemNamed:(NSString *)name inGroup:(NSInteger)groupIndex
{
  XTSideBarItem *group = _roots[groupIndex];

  for (NSInteger i = 0; i < [group numberOfChildren]; ++i) {
    XTSideBarItem *item = [group childAtIndex:i];

    if ([item.title isEqual:name])
      return item;
  }
  return nil;
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView
    numberOfChildrenOfItem:(id)item
{
  _outline = outlineView;
  outlineView.delegate = self;

  NSInteger result = 0;

  if (item == nil) {
    result = [_roots count] + 1;  // Groups plus staging item
  } else if ([item isKindOfClass:[XTSideBarItem class]]) {
    XTSideBarItem *sbItem = (XTSideBarItem *)item;
    result = [sbItem numberOfChildren];
  }
  return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  BOOL result = NO;

  if ([item isKindOfClass:[XTSideBarItem class]]) {
    XTSideBarItem *sbItem = (XTSideBarItem *)item;
    result = [sbItem isItemExpandable];
  }
  return result;
}

- (id)outlineView:(NSOutlineView *)outlineView
            child:(NSInteger)index
           ofItem:(id)item
{
  id result = nil;

  if (item == nil) {
    if (index == 0)
      return _stagingItem;
    else
      result = _roots[index - 1];
  } else if ([item isKindOfClass:[XTSideBarItem class]]) {
    XTSideBarItem *sbItem = (XTSideBarItem *)item;
    result = [sbItem childAtIndex:index];
  }
  return result;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
  if (item == _stagingItem) {
    XTSideBarTableCellView *dataView = (
        XTSideBarTableCellView *)[outlineView makeViewWithIdentifier:@"DataCell"
                                                               owner:self];

    dataView.item = item;
    [dataView.textField setStringValue:[item title]];
    [dataView.textField setEditable:NO];
    [dataView.textField setSelectable:NO];
    [dataView.imageView setImage:[NSImage imageNamed:@"staging"]];
    return dataView;
  } else if ([_roots containsObject:item]) {
    NSTableCellView *headerView =
        [outlineView makeViewWithIdentifier:@"HeaderCell" owner:self];

    [headerView.textField setStringValue:[item title]];
    return headerView;
  } else {
    XTSideBarTableCellView *dataView = (
        XTSideBarTableCellView *)[outlineView makeViewWithIdentifier:@"DataCell"
                                                               owner:self];

    dataView.item = (XTSideBarItem *)item;
    [dataView.textField setStringValue:[item title]];

    if ([item isKindOfClass:[XTStashItem class]]) {
      [dataView.textField setEditable:NO];
      [dataView.textField setSelectable:NO];
    } else {
      // These connections are in the xib, but they get lost, probably
      // when the row view gets copied.
      [dataView.textField setFormatter:_refFormatter];
      [dataView.textField setTarget:_viewController];
      [dataView.textField setAction:@selector(sideBarItemRenamed:)];
      [dataView.textField setEditable:YES];
      [dataView.textField setSelectable:YES];
    }

    if ([item isKindOfClass:[XTLocalBranchItem class]]) {
      [dataView.imageView setImage:[NSImage imageNamed:@"branch"]];
      if (![item isKindOfClass:[XTRemoteBranchItem class]])
        [dataView.button
            setHidden:![[item title] isEqualToString:_currentBranch]];
    } else if ([item isKindOfClass:[XTTagItem class]]) {
      [dataView.imageView setImage:[NSImage imageNamed:@"tag"]];
    } else if ([item isKindOfClass:[XTStashItem class]]) {
      [dataView.imageView setImage:[NSImage imageNamed:@"stash"]];
    } else if ([item isKindOfClass:[XTSubmoduleItem class]]) {
      [dataView.imageView setImage:[NSImage imageNamed:@"submodule"]];
      [dataView.textField setEditable:NO];
    } else {
      [dataView.button setHidden:YES];
      if ([outlineView parentForItem:item] == _roots[XTRemotesGroupIndex])
        [dataView.imageView setImage:[NSImage imageNamed:NSImageNameNetwork]];
    }
    return dataView;
  }
}

#pragma mark - NSOutlineViewDelegate

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
  XTSideBarItem *item = [_outline itemAtRow:_outline.selectedRow];

  if (item.sha != nil) {
    XTDocController *controller = _outline.window.windowController;

    NSAssert([controller isKindOfClass:[XTDocController class]], @"");
    controller.selectedCommitSHA = item.sha;
  }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
  XTSideBarItem *sideBarItem = (XTSideBarItem *)item;

  return (sideBarItem.sha != nil) ||
         [sideBarItem isKindOfClass:[XTRemoteItem class]] ||
         [sideBarItem isKindOfClass:[XTStashItem class]] ||
         [sideBarItem isKindOfClass:[XTSubmoduleItem class]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
  return [_roots containsObject:item];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
    shouldShowOutlineCellForItem:(id)item
{
  // Don't show the Show/Hide control for group items.
  return ![_roots containsObject:item];
}

@end
