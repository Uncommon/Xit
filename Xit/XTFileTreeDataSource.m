#import "XTFileTreeDataSource.h"
#import "XTDocController.h"

@interface XTFileTreeDataSource ()
- (NSTreeNode *)fileTreeForRef:(NSString *)ref;
- (NSTreeNode *)findTreeNodeForPath:(NSString *)path
                             parent:(NSTreeNode *)parent
                              nodes:(NSMutableDictionary *)nodes;
@end


@implementation XTFileTreeDataSource

- (id)init
{
  self = [super init];
  if (self != nil) {
    _root = [self makeNewRoot];
  }

  return self;
}

- (NSTreeNode *)makeNewRoot
{
  XTCommitTreeItem *rootItem = [[XTCommitTreeItem alloc] init];

  rootItem.path = @"root";
  return [NSTreeNode treeNodeWithRepresentedObject:rootItem];
}

- (void)reload
{
  [self.repository executeOffMainThread:^{
    NSString *ref = self.docController.selectedCommitSHA;
    NSTreeNode *newRoot = [self fileTreeForRef:(ref == nil) ? @"HEAD" : ref];

    dispatch_async(dispatch_get_main_queue(), ^{
      _root = newRoot;
      [self.outlineView reloadData];
    });
  }];
}

- (BOOL)isHierarchical
{
  return YES;
}

- (void)updateChangeForNode:(NSTreeNode*)node
{
  XitChange change = XitChangeUnmodified;
  BOOL firstItem = YES;

  for (NSTreeNode *child in [node childNodes]) {
    XTCommitTreeItem *childItem = (XTCommitTreeItem*)[child representedObject];

    if (![child isLeaf])
      [self updateChangeForNode:child];
    if (firstItem)
      change = childItem.change;
    else if (change != childItem.change)
      change = XitChangeMixed;
    firstItem = NO;
  }

  XTCommitTreeItem *item = [node representedObject];

  item.change = change;
}

- (NSTreeNode *)fileTreeForRef:(NSString *)ref
{
  NSTreeNode *newRoot = [self makeNewRoot];
  NSMutableDictionary *nodes = [NSMutableDictionary dictionary];
  NSArray *changeList = [self.repository changesForRef:ref parent:nil];
  NSDictionary *changes = [[NSMutableDictionary alloc]
      initWithCapacity:[changeList count]];
  NSArray *files = [self.repository fileNamesForRef:ref];
  NSMutableArray *deletions =
      [NSMutableArray arrayWithCapacity:[changes count]];

  for (XTFileChange *change in changeList) {
    [changes setValue:@( change.change ) forKey:change.path];
    if (change.change == XitChangeDeleted)
      [deletions addObject:change.path];
  }
  if ([deletions count] > 0)
    files = [files arrayByAddingObjectsFromArray:deletions];

  for (NSString *file in files) {
    XTCommitTreeItem *item = [[XTCommitTreeItem alloc] init];

    item.path = file;
    item.change = (XitChange)[changes[file] integerValue];

    NSString *parentPath = [file stringByDeletingLastPathComponent];
    NSTreeNode *node = [NSTreeNode treeNodeWithRepresentedObject:item];
    NSTreeNode *parentNode =
        [self findTreeNodeForPath:parentPath parent:newRoot nodes:nodes];

    [[parentNode mutableChildNodes] addObject:node];
    nodes[file] = node;
  }
  [self updateChangeForNode:newRoot];

  NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc]
      initWithKey:@"path.lastPathComponent"
        ascending:YES
         selector:@selector(localizedCaseInsensitiveCompare:)];

  [newRoot sortWithSortDescriptors:@[ sortDescriptor ] recursively:YES];
  return newRoot;
}

- (NSTreeNode *)findTreeNodeForPath:(NSString *)path
                             parent:(NSTreeNode *)parent
                              nodes:(NSMutableDictionary *)nodes
{
  if (path.length == 0)
    return parent;
  
  NSTreeNode *pathNode = nodes[path];

  if (pathNode == nil) {
    XTCommitTreeItem *item = [[XTCommitTreeItem alloc] init];

    item.path = path;
    pathNode = [NSTreeNode treeNodeWithRepresentedObject:item];

    NSString *parentPath = [path stringByDeletingLastPathComponent];

    if (parentPath.length == 0) {
      [[parent mutableChildNodes] addObject:pathNode];
    } else {
      NSTreeNode *parentNode =
          [self findTreeNodeForPath:parentPath parent:parent nodes:nodes];
      [[parentNode mutableChildNodes] addObject:pathNode];
    }
    nodes[path] = pathNode;
  }
  return pathNode;
}

- (XTFileChange*)fileChangeAtRow:(NSInteger)row
{
  return [[self.outlineView itemAtRow:row] representedObject];
}

- (NSString*)pathForItem:(id)item
{
  XTCommitTreeItem *treeItem = (XTCommitTreeItem*)
      [(NSTreeNode*)item representedObject];

  return treeItem.path;
}

- (XitChange)changeForItem:(id)item
{
  XTCommitTreeItem *treeItem = (XTCommitTreeItem*)
      [(NSTreeNode*)item representedObject];

  return treeItem.change;
}

- (XitChange)unstagedChangeForItem:(id)item
{
  XTCommitTreeItem *treeItem = (XTCommitTreeItem*)
      [(NSTreeNode*)item representedObject];

  return treeItem.unstagedChange;
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView
    numberOfChildrenOfItem:(id)item
{
  self.outlineView = outlineView;

  NSInteger res = 0;

  if (item == nil) {
    res = [_root.childNodes count];
  } else if ([item isKindOfClass:[NSTreeNode class]]) {
    NSTreeNode *node = (NSTreeNode *)item;
    res = [[node childNodes] count];
  }
  return res;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  NSTreeNode *node = (NSTreeNode *)item;
  BOOL res = [[node childNodes] count] > 0;

  return res;
}

- (id)outlineView:(NSOutlineView *)outlineView
            child:(NSInteger)index
           ofItem:(id)item
{
  id res;

  if (item == nil) {
    res = (_root.childNodes)[index];
  } else {
    NSTreeNode *node = (NSTreeNode *)item;
    res = [node childNodes][index];
  }
  return res;
}

- (id)outlineView:(NSOutlineView *)outlineView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                       byItem:(id)item
{
  NSTreeNode *node = (NSTreeNode *)item;

  return [node representedObject];
}

@end


@implementation XTCommitTreeItem

- (NSString*)description
{
  return self.path;
}

@end
