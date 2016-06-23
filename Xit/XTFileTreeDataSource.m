#import "XTFileTreeDataSource.h"
#import "XTConstants.h"
#import "Xit-Swift.h"

@implementation XTFileTreeDataSource

- (instancetype)init
{
  self = [super init];
  if (self != nil) {
    _root = [NSTreeNode treeNodeWithRepresentedObject:
        [[XTCommitTreeItem alloc] initWithPath:@"root"]];
  }

  return self;
}

- (void)reload
{
  [self.repository executeOffMainThread:^{
    NSTreeNode *newRoot = self.winController.selectedModel.treeRoot;

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

- (XTFileChange*)fileChangeAtRow:(NSInteger)row
{
  if ((row < 0) || (row >= self.outlineView.numberOfRows))
    return nil;
  return [[self.outlineView itemAtRow:row] representedObject];
}

- (NSString*)pathForItem:(id)item
{
  XTCommitTreeItem *treeItem = (XTCommitTreeItem*)
      ((NSTreeNode*)item).representedObject;

  return treeItem.path;
}

- (XitChange)changeForItem:(id)item
{
  XTCommitTreeItem *treeItem = (XTCommitTreeItem*)
      ((NSTreeNode*)item).representedObject;

  return treeItem.change;
}

- (XitChange)unstagedChangeForItem:(id)item
{
  XTCommitTreeItem *treeItem = (XTCommitTreeItem*)
      ((NSTreeNode*)item).representedObject;

  return treeItem.unstagedChange;
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView
    numberOfChildrenOfItem:(id)item
{
  self.outlineView = outlineView;

  NSInteger res = 0;

  if (item == nil) {
    res = _root.childNodes.count;
  } else if ([item isKindOfClass:[NSTreeNode class]]) {
    NSTreeNode *node = (NSTreeNode *)item;
    res = node.childNodes.count;
  }
  return res;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  NSTreeNode *node = (NSTreeNode *)item;
  
  return node.childNodes.count > 0;
}

- (id)outlineView:(NSOutlineView *)outlineView
            child:(NSInteger)index
           ofItem:(id)item
{
  NSTreeNode *root = (item == nil) ? _root : (NSTreeNode*)item;
  
  return (index < root.childNodes.count) ? root.childNodes[index] : nil;
}

- (id)outlineView:(NSOutlineView *)outlineView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                       byItem:(id)item
{
  NSTreeNode *node = (NSTreeNode *)item;

  return node.representedObject;
}

@end


@implementation XTCommitTreeItem

@end
