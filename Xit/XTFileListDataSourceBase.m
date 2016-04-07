#import "XTFileListDataSourceBase.h"
#import "XTConstants.h"
#import "XTDocController.h"
#import "XTFileViewController.h"
#import "XTRepository.h"
#import <objc/runtime.h>

#define XTAssertOverride() \
  NSAssert(false, @"%s must be overridden", sel_getName(_cmd))


@implementation XTFileListDataSourceBase

@synthesize controller = _controller;

- (void)dealloc
{
  [self.docController removeObserver:self forKeyPath:@"selectedCommitSHA"];
}

- (void)reload
{
  XTAssertOverride();
}

- (BOOL)isHierarchical
{
  XTAssertOverride();
  return NO;
}

- (void)setRepository:(XTRepository*)repository
{
  _repository = repository;
  [self reload];
}

- (XTFileViewController*)controller
{
  return _controller;
}

- (void)setController:(XTFileViewController*)controller
{
  @synchronized (self) {
    _controller = controller;
    [controller addObserver:self
                 forKeyPath:@"inStagingView"
                    options:nil
                    context:NULL];
  }
}

- (void)setDocController:(XTDocController *)docController
{
  _docController = docController;
  [_docController addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(selectedCommitSHA))
                      options:NSKeyValueObservingOptionNew
                      context:nil];
}

- (void)updateStagingView
{
  NSTableColumn *unstagedColumn =
      [self.outlineView tableColumnWithIdentifier:@"unstaged"];

  unstagedColumn.hidden = !self.controller.inStagingView;
  // update the column highliht
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
  if ([keyPath isEqualToString:@"selectedCommitSHA"])
    [self reload];
  else if ([keyPath isEqualToString:@"inStagingView"])
    [self updateStagingView];
}

- (XTFileChange*)fileChangeAtRow:(NSInteger)row
{
  return nil;
}

- (NSString*)pathForItem:(id)item
{
  XTAssertOverride();
  return nil;
}

- (XitChange)changeForItem:(id)item
{
  XTAssertOverride();
  return XitChangeUnmodified;
}

- (XitChange)unstagedChangeForItem:(id)item
{
  XTAssertOverride();
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
  NSString * const columnID = tableColumn.identifier;
  const BOOL inStagingView = self.controller.inStagingView;
  const XitChange change = [self changeForItem:item];
  
  if ([columnID isEqualToString:@"main"]) {
    XTFileCellView *cell =
        [outlineView makeViewWithIdentifier:@"fileCell" owner:_controller];

    if (![cell isKindOfClass:[XTFileCellView class]])
      return cell;

    NSString * const path = [self pathForItem:item];

    if ([self outlineView:outlineView isItemExpandable:item])
      cell.imageView.image = [NSImage imageNamed:NSImageNameFolder];
    else
      cell.imageView.image = [[NSWorkspace sharedWorkspace]
          iconForFileType:[path pathExtension]];
    cell.textField.stringValue = [path lastPathComponent];
    
    NSColor *textColor;
    
    if (change == XitChangeDeleted)
      textColor = [NSColor disabledControlTextColor];
    else if ([outlineView isRowSelected:[outlineView rowForItem:item]])
      textColor = [NSColor selectedTextColor];
    else
      textColor = [NSColor textColor];
    cell.textField.textColor = textColor;
    cell.change = change;

    return cell;
  }
  if ([columnID isEqualToString:@"change"]) {
    // Different cell views are used so that the icon is only clickable in
    // staging view.
    if (inStagingView) {
      const XitChange useChange = (change == XitChangeUnmodified) ?
          XitChangeMixed : change;
      XTTableButtonView *cell =
          [outlineView makeViewWithIdentifier:@"staged" owner:_controller];
      
      cell.button.image = [self imageForChange:useChange];
      return cell;
    } else {
      NSTableCellView *cell =
          [outlineView makeViewWithIdentifier:@"change" owner:_controller];
      
      cell.imageView.image = [self imageForChange:change];
      return cell;
    }
  }
  if ([columnID isEqualToString:@"unstaged"]) {
    if (!inStagingView)
      return nil;

    XTTableButtonView *cell =
        [outlineView makeViewWithIdentifier:columnID owner:_controller];
    const XitChange unstagedChange = [self unstagedChangeForItem:item];
    const XitChange useUnstagedChange = (unstagedChange == XitChangeUnmodified) ?
        XitChangeMixed : unstagedChange;
    
    cell.button.image = [self imageForChange:useUnstagedChange];
    return cell;
  }

  return nil;
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


@implementation XTTableButtonView

@end
