#import "XTFileViewController.h"

#import <CoreServices/CoreServices.h>

#import "XTCommitHeaderViewController.h"
#import "XTFileChangesDataSource.h"
#import "XTFileDiffController.h"
#import "XTFileListDataSourceBase.h"
#import "XTFileListDataSource.h"
#import "XTPreviewItem.h"
#import "XTTextPreviewController.h"

const CGFloat kChangeImagePadding = 8;
NSString* const XTContentTabIDDiff = @"diff";
NSString* const XTContentTabIDText = @"text";
NSString* const XTContentTabIDPreview = @"preview";

@interface NSSplitView (Animating)

- (void)animatePosition:(CGFloat)position ofDividerAtIndex:(NSInteger)index;

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
  ((XTPreviewItem*)_filePreview.previewItem).repo = newRepo;
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

  [_fileListOutline sizeToFit];

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
  [_fileListOutline setDelegate:nil];
  [_fileListOutline setDataSource:newDS];
  [_fileListOutline setDelegate:newDS];
  [_fileListOutline reloadData];
}

- (IBAction)changeContentView:(id)sender
{
  const NSInteger selection = [sender selectedSegment];
  NSString *tabIDs[] =
      { XTContentTabIDDiff, XTContentTabIDText, XTContentTabIDPreview };

  NSParameterAssert((selection >= 0) && (selection < 3));
  [self.previewTabView selectTabViewItemWithIdentifier:tabIDs[selection]];
  [self loadSelectedPreview];
}

- (void)clearPreviews
{
  // tell all controllers to clear their previews
  [self.diffController clear];
  [_textController clear];
  _filePreview.previewItem = nil;
}

- (void)loadSelectedPreview
{
  NSIndexSet *selection = [_fileListOutline selectedRowIndexes];
  XTFileListDataSourceBase *dataSource = (XTFileListDataSourceBase*)
      [_fileListOutline dataSource];
  XTFileChange *selectedItem =
      [dataSource fileChangeAtRow:[selection firstIndex]];
  NSString *contentTabID =
      [[self.previewTabView selectedTabViewItem] identifier];

  if ([contentTabID isEqualToString:XTContentTabIDDiff]) {
    [self.diffController loadPath:selectedItem.path
                           commit:_repo.selectedCommit
                       repository:_repo];
  } else if ([contentTabID isEqualToString:XTContentTabIDText]) {
    [_textController loadPath:selectedItem.path
                       commit:_repo.selectedCommit
                   repository:_repo];
  } else if ([contentTabID isEqualToString:XTContentTabIDPreview]) {
    [_filePreview setHidden:NO];

    XTPreviewItem *previewItem = (XTPreviewItem *)_filePreview.previewItem;
    const NSUInteger selectionCount = [selection count];

    if (previewItem == nil) {
      previewItem = [[XTPreviewItem alloc] init];
      previewItem.repo = _repo;
      _filePreview.previewItem = previewItem;
    }

    previewItem.commitSHA = _repo.selectedCommit;
    if (selectionCount != 1) {
      [_filePreview setHidden:YES];
      previewItem.path = nil;
      return;
    }

    previewItem.path = selectedItem.path;
  }
}

- (void)commitSelected:(NSNotification *)note
{
  _headerController.commitSHA = [_repo selectedCommit];
  [self refresh];
}

- (void)fileSelectionChanged:(NSNotification *)note
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

#pragma mark - NSSplitViewDelegate

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
