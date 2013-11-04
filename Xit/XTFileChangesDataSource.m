#import "XTFileChangesDataSource.h"
#import "XTFileListDataSource.h"
#import "XTFileViewController.h"
#import "XTRepository+Parsing.h"

@interface XTFileChangesDataSource ()

@property NSArray *changes;

@end

@implementation XTFileChangesDataSource

- (void)reload
{
  self.changes = [self.repository changesForRef:self.repository.selectedCommit
                                         parent:nil];
  [self.outlineView reloadData];
}

- (BOOL)isHierarchical
{
  return NO;
}

- (XTFileChange*)fileChangeAtRow:(NSInteger)row
{
  return [self.outlineView itemAtRow:row];
}

- (NSString*)pathForItem:(id)item
{
  XTFileChange *change = (XTFileChange*)item;

  return change.path;
}

- (XitChange)changeForItem:(id)item
{
  XTFileChange *change = (XTFileChange*)item;

  return change.change;
}

#pragma mark NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView*)outlineView
    numberOfChildrenOfItem:(id)item
{
  return [self.changes count];
}

- (id)outlineView:(NSOutlineView*)outlineView
            child:(NSInteger)index
           ofItem:(id)item
{
  return self.changes[index];
}

- (BOOL)outlineView:(NSOutlineView*)outlineView isItemExpandable:(id)item
{
  return NO;
}

- (id)outlineView:(NSOutlineView*)outlineView
    objectValueForTableColumn:(NSTableColumn*)tableColumn
                       byItem:(id)item
{
  return [item path];
}

@end
