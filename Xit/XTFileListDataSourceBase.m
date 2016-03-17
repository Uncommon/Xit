#import "XTFileListDataSourceBase.h"
#import "XTFileViewController.h"
#import "XTRepository.h"

@implementation XTFileListDataSourceBase

- (void)dealloc
{
  [self.repository removeObserver:self forKeyPath:@"selectedCommit"];
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
  [_repository addObserver:self
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
  if ([keyPath isEqualToString:@"selectedCommit"] &&
      (object == self.repository))
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

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
  XTFileCellView *cell =
      [outlineView makeViewWithIdentifier:@"fileCell" owner:_controller];

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

  if (change == XitChangeDeleted)
    textColor = [NSColor disabledControlTextColor];
  else if ([outlineView isRowSelected:[outlineView rowForItem:item]])
    textColor = [NSColor selectedTextColor];
  else
    textColor = [NSColor textColor];
  cell.textField.textColor = textColor;
  cell.change = change;

  CGFloat textWidth;
  const NSRect changeFrame = cell.changeImage.frame;
  const NSRect textFrame = cell.textField.frame;

  [cell.changeImage setHidden:change == XitChangeUnmodified];
  if (change == XitChangeUnmodified) {
    textWidth = changeFrame.origin.x + changeFrame.size.width -
                textFrame.origin.x;
  } else {
    cell.changeImage.image = self.controller.changeImages[@( change )];
    textWidth = changeFrame.origin.x - kChangeImagePadding -
                textFrame.origin.x;
  }
  [cell.textField setFrameSize:NSMakeSize(textWidth, textFrame.size.height)];

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
