#import "XTFileViewController.h"

#import <CoreServices/CoreServices.h>

#import "XTConstants.h"
#import "XTCommitHeaderViewController.h"
#import "XTFileListDataSourceBase.h"
#import "XTFileTreeDataSource.h"
#import "XTPreviewController.h"
#import "XTPreviewItem.h"
#import "XTRepository+Commands.h"
#import "XTTextPreviewController.h"
#import "Xit-Swift.h"

NSString* const XTContentTabIDDiff = @"diff";
NSString* const XTContentTabIDText = @"text";
NSString* const XTContentTabIDPreview = @"preview";


@interface NSSplitView (Animating)

/// Animate the divider to the given position
- (void)animatePosition:(CGFloat)position ofDividerAtIndex:(NSInteger)index;

@end


@interface XTFileViewController (Additional)

@end


@implementation XTFileViewController (Additional)

- (void)loadView
{
  [super loadView];

  self.changeImages = @{
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
           object:self.headerController];

  self.commitEntryController = [[XTCommitEntryController alloc]
      initWithNibName:@"XTCommitEntryController" bundle:nil];
  if (self.repo != nil)
    self.commitEntryController.repo = self.repo;
  self.headerTabView.tabViewItems[1].view = self.commitEntryController.view;
  self.previewPath.pathComponentCells = @[];
}

- (IBAction)changeContentView:(id)sender
{
  const NSInteger selection = [sender selectedSegment];
  NSString *tabIDs[] =
      { XTContentTabIDDiff, XTContentTabIDText, XTContentTabIDPreview };
  id contentControllers[] = { self.diffController,
                              self.textController,
                              self.previewController };

  NSParameterAssert((selection >= 0) && (selection < 3));
  [self.previewTabView selectTabViewItemWithIdentifier:tabIDs[selection]];
  self.contentController = contentControllers[selection];
  [self loadSelectedPreview];
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

- (void)clearPreviews
{
  // tell all controllers to clear their previews
  [self.diffController clear];
  [self.textController clear];
  [self.previewController clear];
}

- (void)clear
{
  [self.contentController clear];
  self.previewPath.pathComponentCells = @[];
}

- (void)showUnstagedColumn:(BOOL)shown
{
  NSTableColumn *column =
      [self.fileListOutline tableColumnWithIdentifier:@"unstaged"];

  column.hidden = !shown;
}

- (void)fileSelectionChanged:(NSNotification*)note
{
  [self refreshPreview];
}

- (void)headerResized:(NSNotification*)note
{
  const CGFloat newHeight = [note.userInfo[XTHeaderHeightKey] floatValue];

  [self.headerSplitView animatePosition:newHeight ofDividerAtIndex:0];
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
