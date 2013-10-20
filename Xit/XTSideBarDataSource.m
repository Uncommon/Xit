#import "XTSideBarDataSource.h"
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

#import <Cocoa/Cocoa.h>
@interface XTSideBarDataSource ()
- (NSArray *)loadRoots;
@end

@implementation XTSideBarDataSource

@synthesize roots;

- (id)init
{
  if ((self = [super init]) != nil)
    roots = [self makeRoots];

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
  [outline setTarget:self];
  [outline setDoubleAction:@selector(doubleClick:)];
}

- (void)setRepo:(XTRepository *)newRepo
{
  repo = newRepo;
  if (repo != nil) {
    [repo addReloadObserver:self selector:@selector(repoChanged:)];
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
  [outline performSelectorOnMainThread:@selector(reloadData)
                            withObject:nil
                         waitUntilDone:NO];
}

- (void)reload
{
  [repo executeOffMainThread:^{
    NSArray *newRoots = [self loadRoots];

    dispatch_async(dispatch_get_main_queue(), ^{
      roots = newRoots;
      [outline reloadData];
      // Empty groups get automatically collapsed, so counter that.
      [outline expandItem:nil expandChildren:YES];
    });
  }];
}

- (NSArray *)loadRoots
{
  [self willChangeValueForKey:@"reload"];

  NSMutableDictionary *refsIndex = [NSMutableDictionary dictionary];
  NSMutableArray *branches = [NSMutableArray array];
  NSMutableArray *tags = [NSMutableArray array];
  NSMutableArray *remotes = [NSMutableArray array];
  NSMutableArray *stashes = [NSMutableArray array];
  NSMutableArray *submodules = [NSMutableArray array];

  [self loadBranches:branches tags:tags remotes:remotes refsIndex:refsIndex];
  [self loadStashes:stashes refsIndex:refsIndex];
  [repo readSubmodulesWithBlock:^(GTSubmodule *sub){
    [submodules addObject:[[XTSubmoduleItem alloc] initWithSubmodule:sub]];
  }];

  NSArray *newRoots = [self makeRoots];

  [newRoots[XTBranchesGroupIndex] setChildren:branches];
  [newRoots[XTTagsGroupIndex] setChildren:tags];
  [newRoots[XTRemotesGroupIndex] setChildren:remotes];
  [newRoots[XTStashesGroupIndex] setChildren:stashes];
  [newRoots[XTSubmodulesGroupIndex] setChildren:submodules];

  repo.refsIndex = refsIndex;
  currentBranch = [repo currentBranch];

  [self didChangeValueForKey:@"reload"];
  return newRoots;
}

- (void)loadStashes:(NSMutableArray *)stashes
          refsIndex:(NSMutableDictionary *)refsIndex
{
    [repo readStashesWithBlock:^(NSString *commit, NSString *name)
    {
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

  [repo readRefsWithLocalBlock:localBlock
                   remoteBlock:remoteBlock
                      tagBlock:tagBlock];
}

- (void)doubleClick:(id)sender
{
  id clickedItem = [outline itemAtRow:[outline clickedRow]];

  if ([clickedItem isKindOfClass:[XTSubmoduleItem class]]) {
    XTSubmoduleItem *subItem = (XTSubmoduleItem*)clickedItem;
    NSString *subPath = subItem.submodule.path;
    NSString *rootPath = repo.repoURL.path;
    NSURL *subURL = [NSURL fileURLWithPath:
        [rootPath stringByAppendingPathComponent:subPath]];
    
    [[NSDocumentController sharedDocumentController]
        openDocumentWithContentsOfURL:subURL
                              display:YES
                    completionHandler:NULL];
    // TODO: zoom effect
    // http://github.com/MrNoodle/NoodleKit/blob/master/NSWindow-NoodleEffects.m
  }
}

- (XTLocalBranchItem *)itemForBranchName:(NSString *)branch
{
  XTSideBarItem *branches = roots[XTBranchesGroupIndex];

  for (NSInteger i = 0; i < [branches numberOfChildren]; ++i) {
    XTLocalBranchItem *branchItem = [branches childAtIndex:i];

    if ([branchItem.title isEqual:branch])
      return branchItem;
  }
  return nil;
}

- (XTSideBarItem *)itemNamed:(NSString *)name inGroup:(NSInteger)groupIndex
{
  XTSideBarItem *group = roots[groupIndex];

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
  outline = outlineView;
  outlineView.delegate = self;

  NSInteger result = 0;

  if (item == nil) {
    result = [roots count];
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
    result = roots[index];
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
  if ([roots containsObject:item]) {
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
      [dataView.textField setFormatter:refFormatter];
      [dataView.textField setTarget:viewController];
      [dataView.textField setAction:@selector(sideBarItemRenamed:)];
      [dataView.textField setEditable:YES];
      [dataView.textField setSelectable:YES];
    }

    if ([item isKindOfClass:[XTLocalBranchItem class]]) {
      [dataView.imageView setImage:[NSImage imageNamed:@"branch"]];
      if (![item isKindOfClass:[XTRemoteBranchItem class]])
        [dataView.button
            setHidden:![[item title] isEqualToString:currentBranch]];
    } else if ([item isKindOfClass:[XTTagItem class]]) {
      [dataView.imageView setImage:[NSImage imageNamed:@"tag"]];
    } else if ([item isKindOfClass:[XTStashItem class]]) {
      [dataView.imageView setImage:[NSImage imageNamed:@"stash"]];
    } else if ([item isKindOfClass:[XTSubmoduleItem class]]) {
      [dataView.imageView setImage:[NSImage imageNamed:@"submodule"]];
      [dataView.textField setEditable:NO];
    } else {
      [dataView.button setHidden:YES];
      if ([outlineView parentForItem:item] == roots[XTRemotesGroupIndex])
        [dataView.imageView setImage:[NSImage imageNamed:NSImageNameNetwork]];
    }
    return dataView;
  }
}

#pragma mark - NSOutlineViewDelegate

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
  XTSideBarItem *item = [outline itemAtRow:outline.selectedRow];

  if (item.sha != nil)
    repo.selectedCommit = item.sha;
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
  return [roots containsObject:item];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
    shouldShowOutlineCellForItem:(id)item
{
  // Don't show the Show/Hide control for group items.
  return ![roots containsObject:item];
}

@end
