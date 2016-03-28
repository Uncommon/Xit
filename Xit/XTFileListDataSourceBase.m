#import "XTFileListDataSourceBase.h"
#import "XTConstants.h"
#import "XTDocController.h"
#import "XTFileViewController.h"
#import "XTRepository.h"

@implementation XTFileListDataSourceBase

- (void)dealloc
{
  [self.docController removeObserver:self forKeyPath:@"selectedCommitSHA"];
}

- (void)reload
{
  NSAssert(false, @"reload must be overridden");
}

- (BOOL)isHierarchical
{
  NSAssert(false, @"isHierarchical must be overridden");
  return NO;
}

- (void)setRepository:(XTRepository*)repository
{
  _repository = repository;
  [self reload];
}

- (void)setDocController:(XTDocController *)docController
{
  _docController = docController;
  [_docController addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(selectedCommitSHA))
                      options:NSKeyValueObservingOptionNew
                      context:nil];
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
  NSString *path = NSStringFromSelector(@selector(selectedCommitSHA));
  
  if ([keyPath isEqualToString:path] && (object == self.docController))
    [self reload];
}

- (XTFileChange*)fileChangeAtRow:(NSInteger)row
{
  return nil;
}

- (NSString*)pathForItem:(id)item
{
  NSAssert(false, @"pathForItem must be overridden");
  return nil;
}

- (XitChange)changeForItem:(id)item
{
  NSAssert(false, @"changeForItem must be overridden");
  return XitChangeUnmodified;
}

- (XitChange)unstagedChangeForItem:(id)item
{
  NSAssert(false, @"unstagedChangeForItem must be overridden");
  return XitChangeUnmodified;
}

- (NSImage*)imageForChange:(XitChange)change
{
  return self.controller.changeImages[@( change )];
}

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
  XTFileCellView *cell =
      [outlineView makeViewWithIdentifier:@"fileCell" owner:_controller];
  const BOOL inStagingView =
      [self.docController.selectedCommitSHA isEqualToString:XTStagingSHA];

  if (![cell isKindOfClass:[XTFileCellView class]])
    return cell;

  NSString *path = [self pathForItem:item];

  if ([self outlineView:outlineView isItemExpandable:item])
    cell.imageView.image = [NSImage imageNamed:NSImageNameFolder];
  else
    cell.imageView.image = [[NSWorkspace sharedWorkspace]
        iconForFileType:[path pathExtension]];
  cell.textField.stringValue = [path lastPathComponent];

  NSColor *textColor;
  const XitChange change = [self changeForItem:item];
  const XitChange unstagedChange = [self unstagedChangeForItem:item];

  if (change == XitChangeDeleted)
    textColor = [NSColor disabledControlTextColor];
  else if ([outlineView isRowSelected:[outlineView rowForItem:item]])
    textColor = [NSColor selectedTextColor];
  else
    textColor = [NSColor textColor];
  cell.textField.textColor = textColor;
  cell.change = change;

  const BOOL changeUnmodified = change == XitChangeUnmodified;
  const BOOL unstagedUnmodified = unstagedChange == XitChangeUnmodified;
  const NSRect changeFrame = cell.changeImage.frame;
  const NSRect textFrame = cell.textField.frame;
  CGFloat textRight = changeFrame.origin.x + changeFrame.size.width;

  if (inStagingView) {
    if (changeUnmodified && unstagedUnmodified) {
      cell.changeImage.hidden = YES;
      cell.unstagedImage.hidden = YES;
    } else {
      cell.changeImage.hidden = NO;
      cell.unstagedImage.hidden = NO;
      // Use the "mixed" icon for unmodified so there's always an icon for
      // modified/staged files.
      cell.changeImage.image = [self imageForChange:
          changeUnmodified ? XitChangeMixed : change];
      cell.unstagedImage.image = [self imageForChange:
          unstagedUnmodified ? XitChangeMixed : unstagedChange];
      textRight = cell.unstagedImage.frame.origin.x - kChangeImagePadding;
    }
  } else {
    cell.changeImage.hidden = changeUnmodified;
    cell.unstagedImage.hidden = YES;
    if (change != XitChangeUnmodified)
      textRight = changeFrame.origin.x - kChangeImagePadding;
  }

  [cell.textField setFrameSize:NSMakeSize(
      textRight - textFrame.origin.x,
      textFrame.size.height)];

  return cell;
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
