#import "Xit-Swift.h"
#import "XTSideBarDataSource.h"
#import "XTConstants.h"
#import "XTRefFormatter.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTSideBarTableCellView.h"
#import "NSMutableDictionary+MultiObjectForKey.h"
#import <ObjectiveGit/ObjectiveGit.h>

NSString * const XTStagingSHA = @"";


@interface XTSideBarDataSource ()

- (NSArray *)loadRoots;

@property (readwrite) NSArray<XTSideBarGroupItem*> *roots;
@property (readwrite) XTSideBarItem *stagingItem;
@property NSMutableArray<BOSResource*> *observedResources;

@end


@implementation XTSideBarDataSource

- (instancetype)init
{
  if ((self = [super init]) != nil) {
    _roots = [self makeRoots];
    _stagingItem = [[XTStagingItem alloc] initWithTitle:@"Staging"];
    self.stagingItem = [[XTStagingItem alloc] initWithTitle:@"Staging"];
    self.roots = [self makeRoots];
    _roots = [self makeRoots];
    _stagingItem = [[XTStagingItem alloc] initWithTitle:@"Staging"];
    _observedResources = [[NSMutableArray alloc] init];
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self releaseTeamCityResources];
}

- (void)awakeFromNib
{
  self.outline.target = self;
  self.outline.doubleAction = @selector(doubleClick:);
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
  [self.outline performSelectorOnMainThread:@selector(reloadData)
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
      [self.outline reloadData];
      // Empty groups get automatically collapsed, so counter that.
      [self.outline expandItem:nil expandChildren:YES];
    });
  }];
}


- (void)releaseTeamCityResources
{
  for (BOSResource *resource in self.observedResources)
    [resource removeObserversOwnedBy:self];
}

- (void)updateTeamCity:(XTSideBarItem*)remotes
{
  [self releaseTeamCityResources];
  
  NSArray<XTLocalBranch*> *localBranches = [_repo localBranchesWithError:nil];
  
  if (localBranches.count == 0)
    return;

  for (XTLocalBranch *local in localBranches) {
    XTRemoteBranch *tracked = local.trackingBranch;
    
    if (tracked == nil)
      continue;

    Account *account = [_repo.config teamCityAccount:tracked.remoteName];
    
    if (account == nil)
      continue;
    
    XTTeamCityAPI *api = [[XTServices services] teamCityAPI:account];
    
    if (api == nil)
      continue;
    
    BOSResource *resource =
        [api buildStatus:tracked.shortName.lastPathComponent];
    
    [resource addObserver:self];
    [resource loadIfNeeded];
    [self.observedResources addObject:resource];
  }
}

- (NSImage*)statusImageForRemote:(NSString*)remote
                          branch:(NSString*)branch
{
  XTConfig *config = _repo.config;
  Account *account = [config teamCityAccount:remote];
  
  if (account == nil)
    return nil;
  
  XTTeamCityAPI *api = [[XTServices services] teamCityAPI:account];
  
  if (api == nil)
    return nil;
  
  BOSResource *resource = [api buildStatus:branch];
  NSXMLDocument *document = resource.latestData.content;
  
  if ((document == nil) || ![document isKindOfClass:[NSXMLDocument class]])
    return nil;
  
  NSXMLElement *root = document.rootElement;
  NSXMLNode *status = [root attributeForName:@"status"];
  NSString *statusString = status.stringValue;
  
  if ([statusString isEqualToString:@"SUCCESS"])
    return [NSImage imageNamed:NSImageNameStatusAvailable];
  if ([statusString isEqualToString:@"FAILURE"])
    return [NSImage imageNamed:NSImageNameStatusAvailable];
  return [NSImage imageNamed:NSImageNameStatusNone];
}

- (NSArray *)loadRoots
{
  NSArray *newRoots = [self makeRoots];

  NSMutableDictionary *refsIndex = [NSMutableDictionary dictionary];
  XTSideBarItem *branches = newRoots[XTBranchesGroupIndex];
  NSMutableArray *tags = [NSMutableArray array];
  XTSideBarItem *remotes = newRoots[XTRemotesGroupIndex];
  NSArray<XTStashItem*> *stashes = [self makeStashItems];
  NSArray<XTSubmoduleItem*> *submodules = [self makeSubmoduleItems];

  [self loadBranches:branches tags:tags remotes:remotes refsIndex:refsIndex];

  [newRoots[XTTagsGroupIndex] setChildren:tags];
  [newRoots[XTStashesGroupIndex] setChildren:stashes];
  [newRoots[XTSubmodulesGroupIndex] setChildren:submodules];

  _repo.refsIndex = refsIndex;
  _currentBranch = [_repo currentBranch];

  dispatch_async(dispatch_get_main_queue(), ^{
    [self updateTeamCity:remotes];
  });

  return newRoots;
}

- (void)loadStashes:(NSMutableArray *)stashes
          refsIndex:(NSMutableDictionary *)refsIndex
{
  [_repo readStashesWithBlock:
      ^(NSString *commit, NSUInteger index, NSString *name) {
    XTStashChanges *stashModel = [[XTStashChanges alloc]
        initWithRepository:_repo index:index];
    XTSideBarItem *stash = [[XTStashItem alloc]
        initWithTitle:name model:stashModel];
    
    [stashes addObject:stash];
    [refsIndex addObject:name forKey:commit];
  }];
}

- (XTSideBarItem*)parentForBranch:(NSArray*)components
                        underItem:(XTSideBarItem*)item
{
  if (components.count == 1)
    return item;
  
  NSString *folderName = components[0];

  for (XTSideBarItem *child in item.children) {
    if (child.expandable && [child.title isEqualToString:folderName]) {
      const NSRange subRange = NSMakeRange(1, components.count-1);
      
      return [self parentForBranch:[components subarrayWithRange:subRange]
                         underItem:child];
    }
  }
  
  XTBranchFolderItem *newItem =
      [[XTBranchFolderItem alloc] initWithTitle:folderName];

  [item addChild:newItem];
  return newItem;
}

- (XTSideBarItem*)parentForBranch:(NSString*)branch
                        groupItem:(XTSideBarItem*)group
{
  NSArray *components = [branch componentsSeparatedByString:@"/"];
  
  return [self parentForBranch:components
                     underItem:group];
}

- (void)loadBranches:(XTSideBarItem*)branches
                tags:(NSMutableArray*)tags
             remotes:(XTSideBarItem*)remotes
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
    XTSideBarItem *parent = [self parentForBranch:name groupItem:branches];

    [parent addChild:branch];
    [refsIndex addObject:[@"refs/heads" stringByAppendingPathComponent:name]
                  forKey:commit];
  };

  void (^remoteBlock)(NSString *, NSString *, NSString *) =
      ^(NSString *remoteName, NSString *branchName, NSString *commit) {
    XTSideBarItem *remote = remoteIndex[remoteName];

    if (remote == nil) {
      remote = [[XTRemoteItem alloc] initWithTitle:remoteName];
      [remotes addChild:remote];
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
    XTSideBarItem *parent = [self parentForBranch:branchName groupItem:remote];

    [parent addChild:branch];
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
  id clickedItem = [self.outline itemAtRow:self.outline.clickedRow];

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

#pragma mark - BOSResourceObserver

- (void)resourceChanged:(BOSResource*)resource
                  event:(NSString*)event
{
  // figure out which row it is
  
  [_outline reloadData];
}

- (void)stoppedObservingResource:(BOSResource*)resource
{
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
    textField.stringValue = sbItem.displayTitle;
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
    
    XTSideBarItem *remote = [outlineView parentForItem:item];
    
    if ([remote isKindOfClass:[XTRemoteItem class]]) {
      NSImage *statusImage = [self statusImageForRemote:remote.title
                                                 branch:sbItem.title];
      
      if (statusImage == nil)
        dataView.statusImage.hidden = YES;
      else {
        dataView.statusImage.hidden = NO;
        dataView.statusImage.image = statusImage;
      }
    }
    else
      dataView.statusImage.hidden = YES;
    return dataView;
  }
}

#pragma mark - NSOutlineViewDelegate

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
  XTSideBarItem *item = [_outline itemAtRow:_outline.selectedRow];

  if (item.model != nil) {
    XTWindowController *controller = _outline.window.windowController;

    controller.selectedModel = item.model;
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
