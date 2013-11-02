#import "XTFileListDataSource.h"
#import "XTFileViewController.h"
#import "XTRepository+Parsing.h"

@interface XTFileListDataSource ()
- (NSTreeNode *)fileTreeForRef:(NSString *)ref;
- (NSTreeNode *)findTreeNodeForPath:(NSString *)path
                             parent:(NSTreeNode *)parent
                              nodes:(NSMutableDictionary *)nodes;
@end


@implementation XTFileListDataSource

- (id)init
{
  self = [super init];
  if (self != nil) {
    root = [self makeNewRoot];
  }

  return self;
}

- (void)dealloc
{
  [repo removeObserver:self forKeyPath:@"selectedCommit"];
}

- (NSTreeNode *)makeNewRoot
{
  XTCommitTreeItem *rootItem = [[XTCommitTreeItem alloc] init];

  rootItem.path = @"root";
  return [NSTreeNode treeNodeWithRepresentedObject:rootItem];
}

- (void)setRepo:(XTRepository *)newRepo
{
  repo = newRepo;
  [repo addObserver:self
         forKeyPath:@"selectedCommit"
            options:NSKeyValueObservingOptionNew
            context:nil];
  [self reload];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if ([keyPath isEqualToString:@"selectedCommit"])
    [self reload];
}

- (void)reload
{
  [repo executeOffMainThread:^{
    NSString *ref = repo.selectedCommit;
    NSTreeNode *newRoot = [self fileTreeForRef:(ref == nil) ? @"HEAD" : ref];

    dispatch_async(dispatch_get_main_queue(), ^{
      root = newRoot;
      [table reloadData];
    });
  }];
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
  NSArray *changeList = [repo changesForRef:ref parent:nil];
  NSDictionary *changes = [[NSMutableDictionary alloc]
      initWithCapacity:[changeList count]];
  NSArray *files = [repo fileNamesForRef:ref];
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
    item.change = [changes[file] integerValue];

    NSString *path = [file stringByDeletingLastPathComponent];
    NSTreeNode *node = [NSTreeNode treeNodeWithRepresentedObject:item];

    if (path.length == 0) {
      [[newRoot mutableChildNodes] addObject:node];
    } else {
      NSTreeNode *parentNode =
          [self findTreeNodeForPath:path parent:newRoot nodes:nodes];
      [[parentNode mutableChildNodes] addObject:node];
    }
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
  NSTreeNode *pathNode = nodes[path];

  if (!pathNode) {
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

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView
    numberOfChildrenOfItem:(id)item
{
  table = outlineView;

  NSInteger res = 0;

  if (item == nil) {
    res = [root.childNodes count];
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
    res = (root.childNodes)[index];
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

#pragma mark NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
  XTFileCellView *cell =
      [outlineView makeViewWithIdentifier:@"fileCell" owner:controller];

  if (![cell isKindOfClass:[XTFileCellView class]])
    return cell;

  NSTreeNode *node = (NSTreeNode*)item;
  XTCommitTreeItem *treeItem = (XTCommitTreeItem*)[node representedObject];
  NSString *path = treeItem.path;

  if ([node isLeaf])
    cell.imageView.image = [[NSWorkspace sharedWorkspace]
        iconForFileType:[path pathExtension]];
  else
    cell.imageView.image = [NSImage imageNamed:NSImageNameFolder];
  cell.textField.stringValue = [path lastPathComponent];

  NSColor *textColor;

  if (treeItem.change == XitChangeDeleted)
    textColor = [NSColor disabledControlTextColor];
  else if ([outlineView isRowSelected:[outlineView rowForItem:item]])
    textColor = [NSColor selectedTextColor];
  else
    textColor = [NSColor textColor];
  cell.textField.textColor = textColor;
  cell.change = treeItem.change;

  XitChange change = treeItem.change;
  CGFloat textWidth;
  const NSRect changeFrame = cell.changeImage.frame;
  const NSRect textFrame = cell.textField.frame;

  [cell.changeImage setHidden:change == XitChangeUnmodified];
  if (change == XitChangeUnmodified) {
    textWidth = changeFrame.origin.x + changeFrame.size.width -
                textFrame.origin.x;
  } else {
    cell.changeImage.image = controller.changeImages[@( change )];
    textWidth = changeFrame.origin.x - kChangeImagePadding -
                textFrame.origin.x;
  }
  [cell.textField setFrameSize:NSMakeSize(textWidth, textFrame.size.height)];

  return cell;
}

@end


@implementation XTCommitTreeItem

- (NSString*)description
{
  return self.path;
}

@end


@implementation XTFileCellView

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
  [super setBackgroundStyle:backgroundStyle];
  if (backgroundStyle == NSBackgroundStyleDark)
    self.textField.textColor = [NSColor textColor];
  else if (self.change == XitChangeDeleted)
    self.textField.textColor = [NSColor disabledControlTextColor];
}

@end