#import "XTFileListDataSource.h"
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
    changeImages = @{
        @( XitChangeAdded ) : [NSImage imageNamed:@"added"],
        @( XitChangeCopied ) : [NSImage imageNamed:@"copied"],
        @( XitChangeDeleted ) : [NSImage imageNamed:@"deleted"],
        @( XitChangeModified ) : [NSImage imageNamed:@"modified"],
        @( XitChangeRenamed ) : [NSImage imageNamed:@"renamed"],
        };
  }

  return self;
}

- (void)dealloc
{
  [repo removeObserver:self forKeyPath:@"selectedCommit"];
}

- (NSTreeNode *)makeNewRoot
{
  return [NSTreeNode treeNodeWithRepresentedObject:@"root"];
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
    NSArray *changeList = [repo changesForRef:ref parent:nil];

    changes = [[NSMutableDictionary alloc] initWithCapacity:[changeList count]];
    for (XTFileChange *change in changeList)
      [changes setValue:@( change.change ) forKey:change.path];
    dispatch_async(dispatch_get_main_queue(), ^{
      root = newRoot;
      [table reloadData];
    });
  }];
}

- (NSTreeNode *)fileTreeForRef:(NSString *)ref
{
  NSTreeNode *newRoot = [self makeNewRoot];
  NSMutableDictionary *nodes = [NSMutableDictionary dictionary];
  NSArray *files = [repo fileNamesForRef:ref];

  for (NSString *file in files) {
    NSString *path = [file stringByDeletingLastPathComponent];
    NSTreeNode *node = [NSTreeNode treeNodeWithRepresentedObject:file];

    if (path.length == 0) {
      [[newRoot mutableChildNodes] addObject:node];
    } else {
      NSTreeNode *parentNode =
          [self findTreeNodeForPath:path parent:newRoot nodes:nodes];
      [[parentNode mutableChildNodes] addObject:node];
    }
  }

  NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc]
      initWithKey:@"lastPathComponent"
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
    pathNode = [NSTreeNode treeNodeWithRepresentedObject:path];
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

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
  XTFileCellView *cell =
      [outlineView makeViewWithIdentifier:@"fileCell" owner:controller];

  if (![cell isKindOfClass:[XTFileCellView class]])
    return cell;

  NSTreeNode *node = (NSTreeNode*)item;
  NSString *fileName = (NSString*)node.representedObject;

  if ([node isLeaf])
    cell.imageView.image = [[NSWorkspace sharedWorkspace]
        iconForFileType:[fileName pathExtension]];
  else
    cell.imageView.image = [NSImage imageNamed:NSImageNameFolder];
  cell.textField.stringValue = [fileName lastPathComponent];

  NSNumber *change = changes[fileName];

  [cell.changeImage setHidden:change == nil];
  if (change != nil)
    cell.changeImage.image = changeImages[change];

  return cell;
}

@end

@implementation XTFileCellView

@end