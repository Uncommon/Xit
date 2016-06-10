#import "XTSideBarDataSource.h"
#import "XTConstants.h"
#import "XTDocController.h"
#import "XTRefFormatter.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTSideBarTableCellView.h"
#import "Xit-Swift.h"
#import "NSMutableDictionary+MultiObjectForKey.h"
#import <ObjectiveGit/ObjectiveGit.h>

NSString * const XTStagingSHA = @"";

@interface XTSideBarDataSource ()
- (NSArray *)loadRoots;
@end

@implementation XTSideBarDataSource


- (instancetype)init
{
  if ((self = [super init]) != nil) {
    _roots = [self makeRoots];
    _stagingItem = [[XTStagingItem alloc] initWithTitle:@"Staging"];
  }

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray *)makeRoots
{
  XTSideBarItem *workspace = [[XTSideBarGroupItem alloc] initWithTitle:@"WORKSPACE"];
  XTSideBarItem *branches = [[XTSideBarGroupItem alloc] initWithTitle:@"BRANCHES"];
  XTRemotesItem *remotes = [[XTRemotesItem alloc] initWithTitle:@"REMOTES"];
  XTSideBarItem *tags = [[XTSideBarGroupItem alloc] initWithTitle:@"TAGS"];
  XTSideBarItem *stashes = [[XTSideBarGroupItem alloc] initWithTitle:@"STASHES"];
  XTSideBarItem *subs = [[XTSideBarGroupItem alloc] initWithTitle:@"SUBMODULES"];

  [workspace addChild:_stagingItem];
  return @[ workspace, branches, remotes, tags, stashes, subs ];
}

- (void)awakeFromNib
{
  _outline.target = self;
  _outline.doubleAction = @selector(doubleClick:);
}

- (void)setRepo:(XTRepository *)newRepo
{
  _repo = newRepo;
  if (_repo != nil) {
    _stagingItem.model = [[XTStagingChanges alloc] initWithRepository:_repo];
    [_repo addReloadObserver:self selector:@selector(repoChanged:)];
    [self reload];
  }
}

- (void)repoChanged:(NSNotification *)note
{
  NSArray *paths = note.userInfo[XTPathsKey];

  for (NSString *path in paths) {
    if ([path hasPrefix:@"/refs/"]) {
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
    XTCommitChanges *branchModel =
        [[XTCommitChanges alloc] initWithRepository:_repo sha:commit];
    XTLocalBranchItem *branch =
        [[XTLocalBranchItem alloc] initWithTitle:name.lastPathComponent
                                           model:branchModel];

    [branches addObject:branch];
    [refsIndex addObject:[@"refs/heads" stringByAppendingPathComponent:name]
                  forKey:commit];
  };

  void (^remoteBlock)(NSString *, NSString *, NSString *) =
      ^(NSString *remoteName, NSString *branchName, NSString *commit) {
    XTSideBarItem *remote = remoteIndex[remoteName];

    if (remote == nil) {
      remote = [[XTRemoteItem alloc] initWithTitle:remoteName];
      [remotes addObject:remote];
      remoteIndex[remoteName] = remote;
    }

    XTCommitChanges *branchModel =
        [[XTCommitChanges alloc] initWithRepository:_repo sha:commit];
    XTRemoteBranchItem *branch =
        [[XTRemoteBranchItem alloc] initWithTitle:branchName
                                           remote:remoteName
                                            model:branchModel];
    NSString *branchRef =
        [NSString stringWithFormat:@"refs/remotes/%@/%@", remoteName, branchName];

    [remote addChild:branch];
    [refsIndex addObject:branchRef
                  forKey:commit];
  };

  void (^tagBlock)(NSString *, NSString *) = ^(NSString *name, NSString *commit) {
    XTTagItem *tag;
    XTCommitChanges *tagModel =
        [[XTCommitChanges alloc] initWithRepository:_repo sha:commit];

    if ([name hasSuffix:@"^{}"]) {
      name = [name substringToIndex:name.length - 3];
      tag = tagIndex[name];
      tag.model = tagModel;
    } else {
      tag = [[XTTagItem alloc] initWithTitle:name model:tagModel];
      [tags addObject:tag];
      tagIndex[name] = tag;
    }
    [refsIndex addObject:[@"refs/tags" stringByAppendingPathComponent:name]
                  forKey:commit];
  };

  [_repo readRefsWithLocalBlock:localBlock
                    remoteBlock:remoteBlock
                       tagBlock:tagBlock];
}

- (void)doubleClick:(id)sender
{
  id clickedItem = [_outline itemAtRow:_outline.clickedRow];

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
  }
}

- (XTLocalBranchItem *)itemForBranchName:(NSString *)branch
{
  XTSideBarItem *branches = _roots[XTBranchesGroupIndex];

  for (XTSideBarItem *branchItem in branches.children) {
    if ([branchItem.title isEqual:branch])
      return (XTLocalBranchItem*)branchItem;
  }
  return nil;
}

- (XTSideBarItem *)itemNamed:(NSString *)name inGroup:(NSInteger)groupIndex
{
  XTSideBarItem *group = _roots[groupIndex];

  for (XTSideBarItem *item in group.children) {
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

  if (item == nil) {
    return _roots.count;
  }
  if ([item isKindOfClass:[XTSideBarItem class]]) {
    return ((XTSideBarItem*)item).children.count;
  }
  return 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  BOOL result = NO;

  if ([item isKindOfClass:[XTSideBarItem class]]) {
    XTSideBarItem *sbItem = (XTSideBarItem *)item;
    result = sbItem.expandable;
  }
  return result;
}

- (id)outlineView:(NSOutlineView *)outlineView
            child:(NSInteger)index
           ofItem:(id)item
{
  if (item == nil) {
    return _roots[index];
  } else if ([item isKindOfClass:[XTSideBarItem class]]) {
    return ((XTSideBarItem*)item).children[index];
  }
  return nil;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
  XTSideBarItem *sbItem = (XTSideBarItem*)item;

  if ([_roots containsObject:item]) {
    NSTableCellView *headerView =
        [outlineView makeViewWithIdentifier:@"HeaderCell" owner:self];

    headerView.textField.stringValue = [item title];
    return headerView;
  } else {
    XTSideBarTableCellView *dataView = (XTSideBarTableCellView*)
        [outlineView makeViewWithIdentifier:@"DataCell"
                                      owner:self];
    NSTextField *textField = dataView.textField;

    dataView.item = sbItem;
    dataView.imageView.image = sbItem.icon;
    textField.stringValue = sbItem.title;
    textField.editable = sbItem.editable;
    textField.selectable = sbItem.editable;
    if (sbItem.editable) {
      textField.formatter = _refFormatter;
      textField.target = _viewController;
      textField.action = @selector(sideBarItemRenamed:);
    }
    if (sbItem.current) {
      dataView.button.hidden = NO;
      textField.font =
          [NSFont boldSystemFontOfSize:dataView.textField.font.pointSize];
    }
    else {
      dataView.button.hidden = YES;
      textField.font =
          [NSFont systemFontOfSize:dataView.textField.font.pointSize];
    }
    return dataView;
  }
}

#pragma mark - NSOutlineViewDelegate

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
  XTSideBarItem *item = [_outline itemAtRow:_outline.selectedRow];

  if (item.model != nil) {
    XTDocController *controller = _outline.window.windowController;

    NSAssert([controller isKindOfClass:[XTDocController class]], @"");
    controller.selectedCommitSHA = item.model.shaToSelect;
  }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
  XTSideBarItem *sideBarItem = (XTSideBarItem *)item;

  return sideBarItem.selectable;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
  return [_roots containsObject:item];
}

- (CGFloat)outlineView:(NSOutlineView*)outlineView
     heightOfRowByItem:(id)item
{
  // Using this instead of setting rowSizeStyle because that prevents text
  // from displaying as bold (for the active branch).
  return 20.0;
}

@end
