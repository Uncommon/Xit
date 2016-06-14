#import "XTFileChangesDataSource.h"
#import "XTFileViewController.h"
#import "XTRepository+Parsing.h"
#import "Xit-Swift.h"

@interface XTFileChangesDataSource ()

@property NSMutableArray<XTFileChange*> *changes;

@end

@implementation XTFileChangesDataSource

- (void)reload
{
  [self.repository executeOffMainThread:^{
    NSMutableArray<XTFileChange*> *newChanges = self.winController.selectedModel.changes.mutableCopy;
    NSArray<NSSortDescriptor*> *pathDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"path" ascending:YES] ];
    
    [newChanges sortUsingDescriptors:pathDescriptors];
    
    NSArray<NSString*>
        *newPaths = [newChanges valueForKey:@"path"],
        *oldPaths = [self.changes valueForKey:@"path"];
    NSOrderedSet<NSString*>
        *newSet = [NSOrderedSet orderedSetWithArray:newPaths],
        *oldSet = [NSOrderedSet orderedSetWithArray:oldPaths];
    
    NSIndexSet *deleteIndexes = [oldSet indexesOfObjectsPassingTest:
        ^BOOL(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      return ![newSet containsObject:obj];
    }];
    NSIndexSet *addIndexes = [newSet indexesOfObjectsPassingTest:
        ^BOOL(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      return ![oldSet containsObject:obj];
    }];
    
    NSIndexSet *changeIndexes = nil;
    NSMutableIndexSet *newChangeIndexes = nil;
    
    if (self.changes.count > 0) {
      newChangeIndexes = [NSMutableIndexSet indexSet];
      changeIndexes = [self.changes indexesOfObjectsPassingTest:
          ^BOOL(XTFileChange * _Nonnull obj,
                NSUInteger idx,
                BOOL * _Nonnull stop) {
        const NSUInteger newIndex = [newChanges indexOfObjectPassingTest:
            ^BOOL(XTFileChange * _Nonnull obj2,
                  NSUInteger idx,
                  BOOL * _Nonnull stop) {
          return [obj2.path isEqualTo:obj.path];
        }];
        
        if (newIndex == NSNotFound)
          return NO;
        
        XTFileChange *newChange = newChanges[newIndex];
        
        if ((newChange.change == obj.change) &&
            (newChange.unstagedChange == obj.unstagedChange))
          return NO;
        
        obj.change = newChange.change;
        obj.unstagedChange = newChange.unstagedChange;
        [newChangeIndexes addIndex:newIndex];
        return YES;
      }];
      [self.changes removeObjectsAtIndexes:deleteIndexes];
      [self.changes addObjectsFromArray:[newChanges objectsAtIndexes:addIndexes]];
      [self.changes sortUsingDescriptors:pathDescriptors];
    }
    else
      self.changes = newChanges;
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (self.outlineView.dataSource != self)
        return;
      [self.outlineView beginUpdates];
      if (deleteIndexes.count > 0)
        [self.outlineView removeItemsAtIndexes:deleteIndexes
                                      inParent:nil
                                 withAnimation:NSTableViewAnimationEffectFade];
      if (addIndexes.count > 0)
        [self.outlineView insertItemsAtIndexes:addIndexes
                                      inParent:nil
                                 withAnimation:NSTableViewAnimationEffectFade];
      [self.outlineView endUpdates];
      
      if (changeIndexes.count > 0) {
        NSIndexSet *allColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:
            NSMakeRange(0, self.outlineView.numberOfColumns)];
        
        [self.outlineView reloadDataForRowIndexes:newChangeIndexes
                                    columnIndexes:allColumnIndexes];
      }
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
  return self.changes.count;
}

- (id)outlineView:(NSOutlineView*)outlineView
            child:(NSInteger)index
           ofItem:(id)item
{
  return (index < self.changes.count) ? self.changes[index] : nil;
}

- (BOOL)outlineView:(NSOutlineView*)outlineView isItemExpandable:(id)item
{
  return NO;
}

- (id)outlineView:(NSOutlineView*)outlineView
    objectValueForTableColumn:(NSTableColumn*)tableColumn
                       byItem:(id)item
{
  return ((XTFileChange*)item).path;
}

@end
