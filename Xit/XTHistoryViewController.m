#import "XTHistoryViewController.h"
#import "XTFileViewController.h"
#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import "Xit-Swift.h"
#import "NSAttributedString+XTExtensions.h"

@implementation XTHistoryViewController

- (instancetype)initWithRepository:(XTRepository*)repository
{
  if ((self = [self init]) == nil)
    return nil;

  _repo = repository;
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView
{
  [super loadView];

  // Load the file list view
  NSView *lowerPane = self.mainSplitView.subviews[1];
  
  _fileViewController = [[XTFileViewController alloc]
      initWithNibName:@"XTFileViewController" bundle:nil];
  [lowerPane addSubview:_fileViewController.view];
  [_fileViewController.view setFrameSize:lowerPane.frame.size];

  // Remove intercell spacing so the history lines will connect
  NSSize cellSpacing = _historyTable.intercellSpacing;
  
  cellSpacing.height = 0;
  _historyTable.intercellSpacing = cellSpacing;
}

- (NSString*)nibName
{
  NSLog(@"nibName: %@ (%@)", super.nibName, [self class]);
  return NSStringFromClass([self class]);
}

- (void)windowDidLoad
{
  [_fileViewController windowDidLoad];
}

- (void)setRepo:(XTRepository*)newRepo
{
  _repo = newRepo;
  [_fileViewController setRepo:newRepo];
  self.tableController.repository = newRepo;
}

- (void)reload
{
  [(XTHistoryTableController*)self.historyTable.dataSource reload];
  [_fileViewController reload];
}

- (BOOL)historyHidden
{
  return [self.mainSplitView isSubviewCollapsed:self.mainSplitView.subviews[0]];
}

- (BOOL)detailsHidden
{
  return [self.mainSplitView isSubviewCollapsed:self.mainSplitView.subviews[1]];
}

- (IBAction)toggleHistory:(id)sender
{
  if ([self historyHidden]) {
    // Go back to the un-collapsed size.
    [self.mainSplitView setPosition:_savedHistorySize ofDividerAtIndex:0];
    self.mainSplitView.subviews[0].hidden = NO;
  }
  else {
    if ([self detailsHidden]) {
      // Details pane is collapsed, so swap them.
      const CGFloat minSize =
          [self.mainSplitView minPossiblePositionOfDividerAtIndex:0];
      
      [self.mainSplitView setPosition:minSize ofDividerAtIndex:0];
      self.mainSplitView.subviews[1].hidden = NO;
    }
    else {
      // Both panes are showing, so just collapse history.
      const CGSize historySize = self.mainSplitView.subviews[0].bounds.size;
      const CGFloat newSize =
          [self.mainSplitView minPossiblePositionOfDividerAtIndex:0];
      
      _savedHistorySize = self.mainSplitView.isVertical ? historySize.width
                                                        : historySize.height;
      [self.mainSplitView setPosition:newSize ofDividerAtIndex:0];
    }
    self.mainSplitView.subviews[0].hidden = YES;
  }
}

- (IBAction)toggleDetails:(id)sender
{
  if ([self detailsHidden]) {
    // Go back to the un-collapsed size.
    [self.mainSplitView setPosition:_savedHistorySize ofDividerAtIndex:0];
    self.mainSplitView.subviews[1].hidden = NO;
  }
  else {
    if ([self historyHidden]) {
      // History pane is collapsed, so swap them.
      const CGFloat maxSize =
          [self.mainSplitView maxPossiblePositionOfDividerAtIndex:0];
      
      [self.mainSplitView setPosition:maxSize ofDividerAtIndex:0];
      self.mainSplitView.subviews[0].hidden = NO;
    }
    else {
      // Both panes are showing, so just collapse details.
      // Save the history pane size in both cases because it's the same divider
      // restored to the same position in both cases.
      const CGSize historySize = self.mainSplitView.subviews[0].bounds.size;
      const CGFloat newSize =
          [self.mainSplitView maxPossiblePositionOfDividerAtIndex:0];
      
      _savedHistorySize = self.mainSplitView.isVertical ? historySize.width
                                                        : historySize.height;
      [self.mainSplitView setPosition:newSize ofDividerAtIndex:0];
    }
    self.mainSplitView.subviews[1].hidden = YES;
  }
}

#pragma mark - NSSplitViewDelegate

- (BOOL)splitView:(NSSplitView*)splitView
    shouldAdjustSizeOfSubview:(NSView*)view
{
  return view != splitView.subviews[0];
}

#pragma mark - NSTabViewDelegate

- (void)tabView:(NSTabView *)tabView
    didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
  if ([tabViewItem.identifier isEqualToString:@"tree"])
    [_fileViewController refreshPreview];
}

@end
