#import "XTFileViewController.h"

#import <CoreServices/CoreServices.h>

#import "XTConstants.h"
#import "XTCommitHeaderViewController.h"
#import "XTFileChangesDataSource.h"
#import "XTFileListDataSourceBase.h"
#import "XTFileTreeDataSource.h"
#import "XTPreviewController.h"
#import "XTPreviewItem.h"
#import "XTRepository+Commands.h"
#import "XTTextPreviewController.h"
#import "Xit-Swift.h"

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

@property (nonatomic) BOOL showingStaged;
@property (readonly) BOOL modelCanCommit;
@property id<XTFileContentController> contentController;
@property XTCommitEntryController *commitEntryController;
@property NSDictionary<NSNumber*, NSImage*> *stageImages;
@property (weak) NSButton *lastClickedButton;
@property NSTimer *doubleClickTImer;
@property XTFileEventStream *fileWatcher;

@end


@implementation XTFileViewController

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
  self.commitEntryController.repo = newRepo;
  [[NSNotificationCenter defaultCenter]
      addObserverForName:XTRepositoryIndexChangedNotification
                  object:newRepo
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
    [self indexChanged:note];
  }];
}

- (void)loadView
{
  [super loadView];

  _changeImages = @{
      @( XitChangeAdded ) : [NSImage imageNamed:@"added"],
      @( XitChangeUntracked ) : [NSImage imageNamed:@"added"],
      @( XitChangeCopied ) : [NSImage imageNamed:@"copied"],
      @( XitChangeDeleted ) : [NSImage imageNamed:@"deleted"],
      @( XitChangeModified ) : [NSImage imageNamed:@"modified"],
      @( XitChangeRenamed ) : [NSImage imageNamed:@"renamed"],
      @( XitChangeMixed ) : [NSImage imageNamed:@"mixed"],
      };
  self.stageImages = @{
      @( XitChangeAdded ) : [NSImage imageNamed:@"add"],
      @( XitChangeUntracked ) : [NSImage imageNamed:@"add"],
      @( XitChangeDeleted ) : [NSImage imageNamed:@"delete"],
      @( XitChangeModified ) : [NSImage imageNamed:@"modify"],
      @( XitChangeMixed ) : [NSImage imageNamed:@"mixed"],
      @( XitChangeConflict ) : [NSImage imageNamed:@"conflict"],
      };

  self.fileListOutline.highlightedTableColumn =
      [self.fileListOutline tableColumnWithIdentifier:@"change"];
  [self.fileListOutline sizeToFit];
  self.contentController = self.diffController;

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(fileSelectionChanged:)
             name:NSOutlineViewSelectionDidChangeNotification
           object:self.fileListOutline];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(headerResized:)
             name:XTHeaderResizedNotificaiton
           object:_headerController];

  self.commitEntryController = [[XTCommitEntryController alloc]
      initWithNibName:@"XTCommitEntryController" bundle:nil];
  if (self.repo != nil)
    self.commitEntryController.repo = self.repo;
  self.headerTabView.tabViewItems[1].view = self.commitEntryController.view;
  self.previewPath.pathComponentCells = @[];
}

- (void)windowDidLoad
{
  XTWindowController *controller = (XTWindowController*)
      self.view.window.windowController;

  _fileChangeDS.winController = controller;
  _fileListDS.winController = controller;
  _headerController.winController = controller;
  
  __weak XTFileViewController *weakSelf = self;
  
  [[NSNotificationCenter defaultCenter]
      addObserverForName:XTSelectedModelChangedNotification
                  object:controller
                   queue:nil
              usingBlock:^(NSNotification * _Nonnull note) {
    [weakSelf selectedModelChanged];
  }];
}

- (BOOL)isStaging
{
  return !self.stageSelector.hidden;
}

- (void)setStaging:(BOOL)staging
{
  self.stageSelector.hidden = !staging;
}

- (BOOL)isCommitting
{
  return !self.actionButton.hidden;
}

- (void)setCommitting:(BOOL)committing
{
  [self.headerTabView selectTabViewItemAtIndex:committing ? 1 : 0];
  self.actionButton.hidden = !committing;
}

- (void)selectedModelChanged
{
  XTWindowController *controller =
      (XTWindowController*)self.view.window.windowController;
  id<XTFileChangesModel> newModel = controller.selectedModel;

  if (self.isStaging != newModel.hasUnstaged)
    [self setStaging:newModel.hasUnstaged];
  if (self.isCommitting != newModel.canCommit) {
    [self setCommitting:newModel.canCommit];
    
    // Status icons are different
    const NSInteger
        unstagedIndex = [self.fileListOutline columnWithIdentifier:@"unstaged"],
        stagedIndex = [self.fileListOutline columnWithIdentifier:@"change"];
    const NSRect displayRect = NSUnionRect(
        [self.fileListOutline rectOfColumn:unstagedIndex],
        [self.fileListOutline rectOfColumn:stagedIndex]);
    
    [self.fileListOutline setNeedsDisplayInRect:displayRect];
  }
  _headerController.commitSHA = newModel.shaToSelect;
  [self refreshPreview];
}

- (IBAction)changeFileListView:(id)sender
{
  XTFileListDataSourceBase *newDS = (self.viewSelector.selectedSegment == 0)
      ? _fileChangeDS
      : _fileListDS;
  NSString *columnID = newDS.isHierarchical ? @"main" : @"hidden";
  
  self.fileListOutline.outlineTableColumn =
      [self.fileListOutline tableColumnWithIdentifier:columnID];
  self.fileListOutline.delegate = self;
  self.fileListOutline.dataSource = newDS;
  [self.fileListOutline reloadData];
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

/// Returns the current file list data source, cast to XTFileListDataSourceBase
- (XTFileListDataSourceBase<XTFileListDataSource>*)fileListDataSource
{
  return (XTFileListDataSourceBase<XTFileListDataSource>*)
      self.fileListOutline.dataSource;
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
  XTFileListDataSourceBase<XTFileListDataSource> *dataSource =
      self.fileListDataSource;
  
  [self.repo executeOffMainThread:^{
    [self.repo performSelector:action
                    withObject:[dataSource pathForItem:item]];
    dispatch_async(dispatch_get_main_queue(), ^{
      [dataSource reload];
    });
  }];
}

#pragma clang diagnostic pop

- (BOOL)inStagingView
{
  XTWindowController *controller = self.view.window.windowController;
  
  return controller.selectedModel.hasUnstaged;
}

- (BOOL)modelCanCommit
{
  XTWindowController *controller = self.view.window.windowController;
  
  return controller.selectedModel.canCommit;
}

- (BOOL)showingStaged
{
  return [self.fileListOutline.highlightedTableColumn.identifier
      isEqualToString:XTColumnIDStaged];
}

- (void)setShowingStaged:(BOOL)showingStaged
{
  NSString *columnID = showingStaged ? XTColumnIDStaged : XTColumnIDUnstaged;
  
  self.fileListOutline.highlightedTableColumn =
      [self.fileListOutline tableColumnWithIdentifier:columnID];
  NSAssert(self.fileListOutline.highlightedTableColumn != nil, @"");
  [self.fileListOutline setNeedsDisplay];
  self.stageSelector.selectedSegment = showingStaged ? 1 : 0;
  [self refreshPreview];
}

- (void)selectRowFromButton:(NSButton*)button
{
  const NSInteger row = ((XTTableButtonView*)button.superview).row;
  
  [self.fileListOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                byExtendingSelection:NO];
  [self.view.window makeFirstResponder:self.fileListOutline];
}

- (NSString*)pathFromButton:(NSButton*)button
{
  const NSInteger row = ((XTTableButtonView*)button.superview).row;
  XTFileChange *change = [self.fileListDataSource fileChangeAtRow:row];
  
  return change.path;
}

- (BOOL)checkDoubleClick:(id)sender
{
  if (![sender isKindOfClass:[NSButton class]])
    return false;

  if ((self.lastClickedButton == sender) &&
      (NSApp.currentEvent.clickCount > 1)) {
    self.lastClickedButton = nil;
    return true;
  }
  else {
    self.lastClickedButton = sender;
    return false;
  }
}

- (void)clickButton:(NSButton*)sender staging:(BOOL)staging
{
  if ([self checkDoubleClick:sender]) {
    NSError *error = nil;
    
    sender.enabled = NO;
    if (staging)
      [self.repo stageFile:[self pathFromButton:sender] error:&error];
    else
      [self.repo unstageFile:[self pathFromButton:sender] error:&error];
    [self selectRowFromButton:sender staged:staging];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:XTRepositoryIndexChangedNotification
                      object:self.repo];
  }
  else {
    [self selectRowFromButton:sender staged:!staging];
  }
}

- (IBAction)stageClicked:(id)sender
{
  [self clickButton:sender staging:YES];
}

- (IBAction)unstageClicked:(id)sender
{
  [self clickButton:sender staging:NO];
}

- (void)selectRowFromButton:(NSButton*)button staged:(BOOL)staged
{
  [self selectRowFromButton:button];
  self.showingStaged = staged;
}

- (IBAction)changeStageView:(id)sender
{
  self.showingStaged = self.stageSelector.selectedSegment == 1;
}

- (IBAction)stageAll:(id)sender
{
  NSError *error = nil;
  
  [self.repo stageAllFilesWithError:&error];
  self.showingStaged = YES;
}

- (IBAction)unstageAll:(id)sender
{
  [self.repo unstageAllFiles];
  self.showingStaged = NO;
}

- (IBAction)showIgnored:(id)sender
{
}

- (IBAction)stageUnstageAll:(NSSegmentedControl*)sender
{
  switch (sender.selectedSegment) {
    case 0: [self unstageAll:sender]; break;
    case 1: [self stageAll:sender]; break;
  }
}

- (void)clearPreviews
{
  // tell all controllers to clear their previews
  [self.diffController clear];
  [_textController clear];
  [self.previewController clear];
}

- (void)updatePreviewPath:(NSString*)path isFolder:(BOOL)isFolder
{
  NSArray<NSString*> *components = path.pathComponents;
  NSMutableArray<NSPathComponentCell*> *cells =
      [NSMutableArray arrayWithCapacity:components.count];
  
  [components enumerateObjectsUsingBlock:
      ^(NSString * _Nonnull component, NSUInteger idx, BOOL * _Nonnull stop) {
    NSPathComponentCell *cell = [[NSPathComponentCell alloc] init];
    
    cell.title = component;
    if (!isFolder && idx == components.count - 1)
      cell.image = [[NSWorkspace sharedWorkspace]
                    iconForFileType:component.pathExtension];
    else
      cell.image = [NSImage imageNamed:NSImageNameFolder];
    [cells addObject:cell];
  }];
  self.previewPath.pathComponentCells = cells;
}

- (void)clear
{
  [self.contentController clear];
  self.previewPath.pathComponentCells = @[];
}

- (void)loadSelectedPreview
{
  NSIndexSet *selection = self.fileListOutline.selectedRowIndexes;
  
  if (selection.count == 0) {
    [self clear];
    return;
  }
  
  id selectedItem = [self.fileListOutline itemAtRow:selection.firstIndex];
  XTFileChange *selectedChange =
      [self.fileListDataSource fileChangeAtRow:selection.firstIndex];
  XTWindowController *controller = self.view.window.windowController;

  if (selectedChange == nil) {
    [self clear];
    return;
  }
  [self updatePreviewPath:selectedChange.path
                 isFolder:[self.fileListOutline isExpandable:selectedItem]];
  [self.contentController loadPath:selectedChange.path
                             model:controller.selectedModel
                            staged:self.showingStaged];
  
  // Swift bridge weirdness
  OS_dispatch_queue *queue = (OS_dispatch_queue*)dispatch_get_main_queue();
  NSString *fullPath = [self.repo.repoURL.path
                       stringByAppendingPathComponent:selectedChange.path];
  
  self.fileWatcher = self.inStagingView ?
      [[XTFileEventStream alloc] initWithPath:fullPath
                                 excludePaths:[NSArray array]
                                        queue:queue
                                      latency:0.5
                                     callback:^(NSArray<NSString*> *paths) {
        [self loadSelectedPreview];
      }]
      : nil;
}

- (void)showUnstagedColumn:(BOOL)shown
{
  NSTableColumn *column =
      [self.fileListOutline tableColumnWithIdentifier:@"unstaged"];

  column.hidden = !shown;
}

- (void)indexChanged:(NSNotification*)note
{
  if (self.inStagingView)
    [self.fileListDataSource reload];
  
  // Ideally, check to see if the selected file has changed
  if (self.modelCanCommit)
    [self loadSelectedPreview];
}

- (void)fileSelectionChanged:(NSNotification*)note
{
  [self refreshPreview];
}

- (void)headerResized:(NSNotification*)note
{
  const CGFloat newHeight = [note.userInfo[XTHeaderHeightKey] floatValue];

  [_headerSplitView animatePosition:newHeight ofDividerAtIndex:0];
}

- (void)reload
{
  [self.fileListDataSource reload];
}

- (void)refreshPreview
{
  [self loadSelectedPreview];
  [_filePreview refreshPreviewItem];
}

- (NSImage*)imageForChange:(XitChange)change
{
  return self.changeImages[@( change )];
}

- (XitChange)displayChangeForChange:(XitChange)change
                        otherChange:(XitChange)otherChange
{
  return (change == XitChangeUnmodified) &&
         (otherChange != XitChangeUnmodified) ?
         XitChangeMixed : change;
}

- (NSImage*)stagingImageForChange:(XitChange)change
                      otherChange:(XitChange)otherChange
{
  change = [self displayChangeForChange:change otherChange:otherChange];
  return self.stageImages[@( change )];
}

- (XTTableButtonView*)tableButtonView:(NSString*)identifier
                               change:(XitChange)change
                          otherChange:(XitChange)otherChange
                                  row:(NSInteger)row
{
  XTTableButtonView *cell =
      [self.fileListOutline makeViewWithIdentifier:identifier owner:self];
  XTRolloverButton *button = (XTRolloverButton*)cell.button;
  
  ((NSButtonCell*)button.cell).imageDimsWhenDisabled = NO;
  if (self.modelCanCommit) {
    button.image = [self stagingImageForChange:change
                                   otherChange:otherChange];
    button.enabled =
        [self displayChangeForChange:change otherChange:otherChange] !=
            XitChangeMixed;
  }
  else {
    button.image = [self imageForChange:change];
    button.enabled = NO;
  }
  cell.row = row;
  return cell;
}

#pragma mark NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
  XTFileListDataSourceBase<XTFileListDataSource> *dataSource =
      self.fileListDataSource;
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
                              iconForFileType:path.pathExtension];
    cell.textField.stringValue = path.lastPathComponent;
    
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
    if (self.inStagingView) {
      return [self tableButtonView:@"staged"
                            change:change
                       otherChange:[dataSource unstagedChangeForItem:item]
                               row:[outlineView rowForItem:item]];
    } else {
      NSTableCellView *cell =
          [outlineView makeViewWithIdentifier:@"change" owner:self];
      
      cell.imageView.image = [self imageForChange:change];
      return cell;
    }
  }
  if ([columnID isEqualToString:@"unstaged"]) {
    if (!self.inStagingView)
      return nil;
    return [self tableButtonView:@"unstaged"
                          change:[dataSource unstagedChangeForItem:item]
                     otherChange:change
                             row:[outlineView rowForItem:item]];
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
  if ([rowView isKindOfClass:[XTFileRowView class]])
    ((XTFileRowView*)rowView).outlineView = self.fileListOutline;
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
  NSView *targetView = self.subviews[index];
  NSRect endFrame = targetView.frame;

  if (self.vertical)
      endFrame.size.width = position;
  else
      endFrame.size.height = position;

  NSDictionary *windowResize = @{
      NSViewAnimationTargetKey: targetView,
      NSViewAnimationEndFrameKey: [NSValue valueWithRect: endFrame],
      };
  NSViewAnimation *animation =
      [[NSViewAnimation alloc] initWithViewAnimations:@[ windowResize ]];

  animation.animationBlockingMode = NSAnimationBlocking;
  animation.duration = 0.2;
  [animation startAnimation];
}

@end
