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

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
  if (object == self.repository)
    [self reload];
}

- (void)setRepository:(XTRepository*)repository
{
  _repository = repository;
  [_repository addObserver:self
               forKeyPath:@"selectedCommit"
                  options:NSKeyValueObservingOptionNew
                  context:nil];
  [self reload];
}

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

- (XTFileChange*)fileChangeAtRow:(NSInteger)row
{
  return [self.outlineView itemAtRow:row];
}

- (NSView*)outlineView:(NSOutlineView*)outlineView
    viewForTableColumn:(NSTableColumn*)tableColumn
                  item:(id)item
{
  XTFileCellView *cell =
      [outlineView makeViewWithIdentifier:@"fileCell" owner:self.controller];

  if (![cell isKindOfClass:[XTFileCellView class]])
    return cell;

  XTFileChange *change = (XTFileChange*)item;
  NSString *path = change.path;

  cell.textField.stringValue = [path lastPathComponent];
  cell.imageView.image = [[NSWorkspace sharedWorkspace]
      iconForFileType:[path pathExtension]];

  NSColor *textColor;

  if (change.change == XitChangeDeleted)
    textColor = [NSColor disabledControlTextColor];
  else if ([outlineView isRowSelected:[outlineView rowForItem:item]])
    textColor = [NSColor selectedTextColor];
  else
    textColor = [NSColor textColor];
  cell.textField.textColor = textColor;
  cell.change = change.change;

  XitChange changeType = change.change;
  CGFloat textWidth;
  const NSRect changeFrame = cell.changeImage.frame;
  const NSRect textFrame = cell.textField.frame;

  [cell.changeImage setHidden:changeType == XitChangeUnmodified];
  if (changeType == XitChangeUnmodified) {
    textWidth = changeFrame.origin.x + changeFrame.size.width -
                textFrame.origin.x;
  } else {
    cell.changeImage.image = self.controller.changeImages[@( changeType )];
    textWidth = changeFrame.origin.x - kChangeImagePadding -
                textFrame.origin.x;
  }
  [cell.textField setFrameSize:NSMakeSize(textWidth, textFrame.size.height)];

  return cell;
}

@end
