#import "XTFileViewController.h"

#import <CoreServices/CoreServices.h>

#import "XTCommitHeaderViewController.h"
#import "XTFileListDataSource.h"
#import "XTPreviewItem.h"
#import "XTRepository.h"
#import "XTTextPreviewController.h"
#import <RBSplitView.h>

@interface NSSplitView (Animating)

- (void)animatePosition:(CGFloat)position ofDividerAtIndex:(NSInteger)index;

@end

@interface XTFileViewController ()

@end


@implementation XTFileViewController

+ (BOOL)fileNameIsText:(NSString*)name
{
  NSArray *extensionlessNames = @[
      @"AUTHORS", @"CONTRIBUTING", @"COPYING", @"LICENSE", @"Makefile",
      @"README", ];

  for (NSString *extensionless in extensionlessNames)
    if ([name isCaseInsensitiveLike:extensionless])
      return YES;

  NSString *extension = [name pathExtension];
  const CFStringRef utType = UTTypeCreatePreferredIdentifierForTag(
      kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL);
  const Boolean result = UTTypeConformsTo(utType, kUTTypeText);
  
  CFRelease(utType);
  return result;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setRepo:(XTRepository *)newRepo
{
  repo = newRepo;
  [fileListDS setRepo:newRepo];
  headerController.repository = newRepo;
  ((XTPreviewItem *)filePreview.previewItem).repo = newRepo;
}

- (void)awakeFromNib
{
  // -[NSOutlineView makeViewWithIdentifier:owner:] causes this to get called
  // again after the initial load.
  if ([[splitView subviews] count] == 2)
    return;

  // For some reason the splitview comes with preexisting subviews.
  NSArray *subviews = [[splitView subviews] copy];

  for (NSView *sub in subviews)
    [sub removeFromSuperview];
  [splitView addSubview:leftPane];
  [splitView addSubview:rightPane];
  [splitView setDivider:[NSImage imageNamed:@"splitter"]];
  [splitView setDividerThickness:1.0];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(fileSelectionChanged:)
             name:NSOutlineViewSelectionDidChangeNotification
           object:fileListOutline];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(headerResized:)
             name:XTHeaderResizedNotificaiton
           object:headerController];
}

- (void)updatePreview
{
  NSIndexSet *selection = [fileListOutline selectedRowIndexes];
  const NSUInteger selectionCount = [selection count];
  XTPreviewItem *previewItem = (XTPreviewItem *)filePreview.previewItem;

  if (previewItem == nil) {
    previewItem = [[XTPreviewItem alloc] init];
    previewItem.repo = repo;
    filePreview.previewItem = previewItem;
  }

  previewItem.commitSHA = repo.selectedCommit;
  if (selectionCount != 1) {
    [filePreview setHidden:YES];
    previewItem.path = nil;
    return;
  }

  NSTreeNode *selectedNode = [fileListOutline itemAtRow:[selection firstIndex]];
  XTCommitTreeItem *selectedItem = (XTCommitTreeItem*)
      [selectedNode representedObject];

  if ([[self class] fileNameIsText:selectedItem.path]) {
    [self.previewTabView selectTabViewItemWithIdentifier:@"text"];
    [textPreview loadPath:selectedItem.path
                   commit:repo.selectedCommit
               repository:repo];
  } else {
    [self.previewTabView selectTabViewItemWithIdentifier:@"preview"];
    [filePreview setHidden:NO];
    previewItem.path = selectedItem.path;
  }
}

- (void)commitSelected:(NSNotification *)note
{
  headerController.commitSHA = [repo selectedCommit];
  [self refresh];
}

- (void)fileSelectionChanged:(NSNotification *)note
{
  [self refresh];
}

- (void)headerResized:(NSNotification*)note
{
  const CGFloat newHeight = [[note userInfo][XTHeaderHeightKey] floatValue];

  [headerSplitView animatePosition:newHeight ofDividerAtIndex:0];
}

- (void)refresh
{
  [self updatePreview];
  [filePreview refreshPreviewItem];
}

#pragma mark - NSSplitViewDelegate

- (BOOL)splitView:(NSSplitView*)splitView
    shouldAdjustSizeOfSubview:(NSView*)subview
{
  if (subview == headerController.view)
    return NO;
  return YES;
}

#pragma mark - RBSplitViewDelegate

const CGFloat kSplitterBonus = 4;

- (NSRect)splitView:(RBSplitView *)sender
         cursorRect:(NSRect)rect
         forDivider:(NSUInteger)divider
{
  if ([sender isVertical]) {
    rect.origin.x -= kSplitterBonus;
    rect.size.width += kSplitterBonus * 2;
  }
  return rect;
}

- (NSUInteger)splitView:(RBSplitView *)sender
        dividerForPoint:(NSPoint)point
              inSubview:(RBSplitSubview *)subview
{
  // Assume sender is the file list split view
  const NSRect subFrame = [subview frame];
  NSRect frame1, frame2, remainder;
  NSUInteger position = [subview position];
  NSRectEdge edge1 = [sender isVertical] ? NSMinXEdge : NSMinYEdge;
  NSRectEdge edge2 = [sender isVertical] ? NSMaxXEdge : NSMaxYEdge;

  NSDivideRect(subFrame, &frame1, &remainder, kSplitterBonus, edge1);
  NSDivideRect(subFrame, &frame2, &remainder, kSplitterBonus, edge2);

  if ([sender mouse:point inRect:frame1] && (position > 0))
    return position - 1;
  else if ([sender mouse:point inRect:frame2])
    return position;
  return NSNotFound;
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
