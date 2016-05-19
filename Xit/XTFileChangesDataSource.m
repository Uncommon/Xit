#import "XTFileChangesDataSource.h"
#import "XTDocController.h"
#import "XTFileViewController.h"
#import "XTRepository+Parsing.h"

@interface XTFileChangesDataSource ()

@property NSArray<XTFileChange*> *changes;

@end

@implementation XTFileChangesDataSource

- (void)reload
{
  [self.repository executeOffMainThread:^{
    self.changes = [self.repository
        changesForRef:self.docController.selectedCommitSHA parent:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.outlineView reloadData];
    });
  }];
}

- (BOOL)isHierarchical
{
  return NO;
}

- (XTFileChange*)fileChangeAtRow:(NSInteger)row
{
  if (row >= self.changes.count)
    return nil;
  return self.changes[row];
}

- (NSString*)pathForItem:(id)item
{
  XTFileChange *change = (XTFileChange*)item;

  return change.path;
}

- (XitChange)changeForItem:(id)item
{
  return [[self class] transformDisplayChange:((XTFileChange*)item).change];
}

- (XitChange)unstagedChangeForItem:(id)item
{
  return [[self class]
      transformDisplayChange:((XTFileChange*)item).unstagedChange];
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
  return [(XTFileChange*)item path];
}

@end
