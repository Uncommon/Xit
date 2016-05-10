#import "XTFileViewController.h"

#import <CoreServices/CoreServices.h>

#import "XTConstants.h"
#import "XTCommitHeaderViewController.h"
#import "XTDocController.h"
#import "XTFileChangesDataSource.h"
#import "XTFileDiffController.h"
#import "XTFileListDataSourceBase.h"
#import "XTFileTreeDataSource.h"
#import "XTFileListView.h"
#import "XTPreviewController.h"
#import "XTPreviewItem.h"
#import "XTTextPreviewController.h"

const CGFloat kChangeImagePadding = 8;
NSString* const XTContentTabIDDiff = @"diff";
NSString* const XTContentTabIDText = @"text";
NSString* const XTContentTabIDPreview = @"preview";
NSString* const XTColumnIDStaged = @"change";
NSString* const XTColumnIDUnstaged = @"unstaged";


@interface NSSplitView (Animating)

/// Animate the divider to the given position
- (void)animatePosition:(CGFloat)position ofDividerAtIndex:(NSInteger)index;

@end


@interface XTFileViewController ()

@property (readwrite) BOOL inStagingView;
@property BOOL showingStaged;
@property id<XTFileContentController> contentController;

@end


@implementation XTFileViewController

@synthesize inStagingView;

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setRepo:(XTRepository *)newRepo
{
  _repo = newRepo;
  _fileChangeDS.repository = newRepo;
  _fileListDS.repository = newRepo;
  _headerController.repository = newRepo;
  ((XTPreviewItem*)_filePreview.previewItem).repo = newRepo;
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(repoChanged:)
             name:XTRepositoryChangedNotification
           object:newRepo];
}

- (void)loadView
{
  [super loadView];

  _changeImages = @{
      @( XitChangeAdded ) : [NSImage imageNamed:@"added"],
      @( XitChangeCopied ) : [NSImage imageNamed:@"copied"],
      @( XitChangeDeleted ) : [NSImage imageNamed:@"deleted"],
      @( XitChangeModified ) : [NSImage imageNamed:@"modified"],
      @( XitChangeRenamed ) : [NSImage imageNamed:@"renamed"],
      @( XitChangeMixed ) : [NSImage imageNamed:@"mixed"],
      };

  _fileListOutline.highlightedTableColumn =
      [_fileListOutline tableColumnWithIdentifier:@"change"];
  [_fileListOutline sizeToFit];
  self.contentController = self.diffController;

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(fileSelectionChanged:)
             name:NSOutlineViewSelectionDidChangeNotification
           object:_fileListOutline];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(headerResized:)
             name:XTHeaderResizedNotificaiton
           object:_headerController];
}

- (void)windowDidLoad
{
  XTDocController *controller = (XTDocController*)
      self.view.window.windowController;

  NSAssert([controller isKindOfClass:[XTDocController class]], @"");
  _fileChangeDS.docController = controller;
  _fileListDS.docController = controller;
  _headerController.docController = controller;
  [controller addObserver:self
               forKeyPath:@"selectedCommitSHA"
                  options:NSKeyValueObservingOptionNew |
                          NSKeyValueObservingOptionOld
                  context:NULL];
}

- (void)
observeValueForKeyPath:(NSString*)keyPath
              ofObject:(id)object
                change:(NSDictionary<NSString *,id> *)change
               context:(void*)context
{
  if ([keyPath isEqualToString:@"selectedCommitSHA"]) {
    NSString * const oldSHA = change[NSKeyValueChangeOldKey];
    NSString * const newSHA = change[NSKeyValueChangeNewKey];
    const BOOL wasStaging = (oldSHA != (NSString*)[NSNull null]) &&
                            [oldSHA isEqualToString:XTStagingSHA];
    const BOOL nowStaging = (newSHA != (NSString*)[NSNull null]) &&
                            [newSHA isEqualToString:XTStagingSHA];
    
    if (wasStaging != nowStaging)
      self.inStagingView = nowStaging;
  }
}

- (IBAction)changeFileListView:(id)sender
{
  XTFileListDataSourceBase *newDS = _fileChangeDS;

  if (self.viewSelector.selectedSegment == 1)
    newDS = _fileListDS;
  if (newDS.isHierarchical)
    [_fileListOutline setOutlineTableColumn:
        [_fileListOutline tableColumnWithIdentifier:@"main"]];
  else
    [_fileListOutline setOutlineTableColumn:
        [_fileListOutline tableColumnWithIdentifier:@"hidden"]];
  [_fileListOutline setDelegate:self];
  [_fileListOutline setDataSource:newDS];
  [_fileListOutline reloadData];
}

- (IBAction)changeContentView:(id)sender
{
  const NSInteger selection = [sender selectedSegment];
  NSString *tabIDs[] =
      { XTContentTabIDDiff, XTContentTabIDText, XTContentTabIDPreview };
  id contentControllers[] = { self.diffController,
                              _textController,
                              self.previewController };

  NSParameterAssert((selection >= 0) && (selection < 3));
  [self.previewTabView selectTabViewItemWithIdentifier:tabIDs[selection]];
  self.contentController = contentControllers[selection];
  [self loadSelectedPreview];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

/**
  Performs the given selector off the main thread, and refreshes the file list.
  Without this, methods like stageClicked: and unstageClicked: have too much
  common code.
 */
- (void)performRepoAction:(SEL)action onFileListItem:(id)item
{
  XTFileListDataSourceBase *dataSource =
  (XTFileListDataSourceBase*)_fileListOutline.dataSource;
  
  [_repo executeOffMainThread:^{
    [_repo performSelector:action withObject:[dataSource pathForItem:item]];
    dispatch_async(dispatch_get_main_queue(), ^{
      [dataSource reload];
    });
  }];
}

#pragma clang diagnostic pop

- (BOOL)showingStaged
{
  return [_fileListOutline.highlightedTableColumn.identifier
      isEqualToString:XTColumnIDStaged];
}

- (void)setShowingStaged:(BOOL)showingStaged
{
  NSString *columnID = showingStaged ? XTColumnIDStaged : XTColumnIDUnstaged;
  
  _fileListOutline.highlightedTableColumn =
      [_fileListOutline tableColumnWithIdentifier:columnID];
  NSAssert(_fileListOutline.highlightedTableColumn != nil, @"");
  [_fileListOutline setNeedsDisplay];
  [self refresh];
}

- (void)selectRowFromButton:(NSButton*)button
{
  const NSInteger row = ((XTTableButtonView*)button.superview).row;
  
  [_fileListOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                byExtendingSelection:NO];
  [self.view.window makeFirstResponder:_fileListOutline];
}

- (IBAction)stageClicked:(id)sender
{
  self.showingStaged = NO;
  [self selectRowFromButton:sender];
  // on single click, show workspace diff
  // on double click, stage file
}

- (IBAction)unstageClicked:(id)sender
{
  self.showingStaged = YES;
  [self selectRowFromButton:sender];
}

- (void)clearPreviews
{
  // tell all controllers to clear their previews
  [self.diffController clear];
  [_textController clear];
  [self.previewController clear];
}

- (void)loadSelectedPreview
{
  NSIndexSet *selection = [_fileListOutline selectedRowIndexes];
  XTFileListDataSourceBase *dataSource = (XTFileListDataSourceBase*)
      [_fileListOutline dataSource];
  XTFileChange *selectedItem =
      [dataSource fileChangeAtRow:[selection firstIndex]];
  XTDocController *docController = self.view.window.windowController;

  if (self.inStagingView) {
    if (self.showingStaged)
      [self.contentController loadStagedPath:selectedItem.path
                                  repository:_repo];
    else
      [self.contentController loadUnstagedPath:selectedItem.path
                                    repository:_repo];
  }
  else {
    NSAssert([docController isKindOfClass:[XTDocController class]], @"");
    [self.contentController loadPath:selectedItem.path
                              commit:docController.selectedCommitSHA
                          repository:_repo];
  }
}

- (void)showUnstagedColumn:(BOOL)shown
{
  NSTableColumn *column =
      [_fileListOutline tableColumnWithIdentifier:@"unstaged"];

  column.hidden = !shown;
}

- (void)repoChanged:(NSNotification*)note
{
  NSArray *paths = note.userInfo[XTPathsKey];
  
  if (self.inStagingView && ([paths count] != 0))
    for (NSString *path in paths)
      if ([path isEqualToString:@"/"]) {
        // ideally check the mod date on /index
        [_fileListDS reload];
        break;
      }
}

- (void)commitSelected:(NSNotification*)note
{
  XTDocController *docController = self.view.window.windowController;

  NSAssert([docController isKindOfClass:[XTDocController class]], @"");
  _headerController.commitSHA = docController.selectedCommitSHA;
  [self showUnstagedColumn:
      [docController.selectedCommitSHA isEqualToString:XTStagingSHA]];
  [self refresh];
}

- (void)fileSelectionChanged:(NSNotification*)note
{
  [self refresh];
}

- (void)headerResized:(NSNotification*)note
{
  const CGFloat newHeight = [[note userInfo][XTHeaderHeightKey] floatValue];

  [_headerSplitView animatePosition:newHeight ofDividerAtIndex:0];
}

- (void)refresh
{
  [self loadSelectedPreview];
  [_filePreview refreshPreviewItem];
}

- (NSImage*)imageForChange:(XitChange)change
{
  return self.changeImages[@( change )];
}

#pragma mark NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
  XTFileListDataSourceBase *dataSource =
      (XTFileListDataSourceBase*)_fileListOutline.dataSource;
  NSString * const columnID = tableColumn.identifier;
  const XitChange change = [dataSource changeForItem:item];
  
  if ([columnID isEqualToString:@"main"]) {
    XTFileCellView *cell =
        [outlineView makeViewWithIdentifier:@"fileCell" owner:self];
    
    if (![cell isKindOfClass:[XTFileCellView class]])
      return cell;
    
    NSString * const path = [dataSource pathForItem:item];
    
    if ([dataSource outlineView:outlineView isItemExpandable:item])
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
          [outlineView makeViewWithIdentifier:@"staged" owner:self];
      
      cell.button.image = [self imageForChange:useChange];
      cell.row = [outlineView rowForItem:item];
      return cell;
    } else {
      NSTableCellView *cell =
          [outlineView makeViewWithIdentifier:@"change" owner:self];
      
      cell.imageView.image = [self imageForChange:change];
      return cell;
    }
  }
  if ([columnID isEqualToString:@"unstaged"]) {
    if (!inStagingView)
      return nil;
    
    XTTableButtonView *cell =
        [outlineView makeViewWithIdentifier:columnID owner:self];
    const XitChange unstagedChange = [dataSource unstagedChangeForItem:item];
    const XitChange useUnstagedChange = (unstagedChange == XitChangeUnmodified) ?
        XitChangeMixed : unstagedChange;
    
    cell.button.image = [self imageForChange:useUnstagedChange];
    cell.row = [outlineView rowForItem:item];
    return cell;
  }
  
  return nil;
}

- (NSTableRowView*)outlineView:(NSOutlineView *)outlineView
                rowViewForItem:(id)item
{
  return [[XTFileRowView alloc] init];
}

- (void)outlineView:(NSOutlineView*)outlineView
      didAddRowView:(NSTableRowView*)rowView
             forRow:(NSInteger)row
{
  XTFileRowView *xtRowView = (XTFileRowView*)rowView;
  
  xtRowView.outlineView = _fileListOutline;
}

#pragma mark NSSplitViewDelegate

- (BOOL)splitView:(NSSplitView*)splitView
    shouldAdjustSizeOfSubview:(NSView*)subview
{
  if (splitView == _headerSplitView)
    return subview != _headerController.view;
  if (splitView == _fileSplitView)
    return subview != _leftPane;
  return YES;
}

@end


@implementation NSSplitView (Animating)

- (void)animatePosition:(CGFloat)position ofDividerAtIndex:(NSInteger)index
{
  NSView *targetView = [self subviews][index];
  NSRect endFrame = [targetView frame];

  if ([self isVertical])
      endFrame.size.width = position;
  else
      endFrame.size.height = position;

  NSDictionary *windowResize = @{
      NSViewAnimationTargetKey: targetView,
      NSViewAnimationEndFrameKey: [NSValue valueWithRect: endFrame],
      };
  NSViewAnimation *animation =
      [[NSViewAnimation alloc] initWithViewAnimations:@[ windowResize ]];

  [animation setAnimationBlockingMode:NSAnimationBlocking];
  [animation setDuration:0.2];
  [animation startAnimation];
}

@end
