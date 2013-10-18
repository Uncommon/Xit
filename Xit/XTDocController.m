#import "XTDocController.h"
#import "XTDocument.h"
#import "XTHistoryViewController.h"
#import "XTRepository.h"
#import "XTStageViewController.h"
#import "XTStatusView.h"

#import <Cocoa/Cocoa.h>
@interface XTDocController (Private)

- (void)loadViewController:(NSViewController *)viewController
                     onTab:(NSInteger)tabId;

@end

@implementation XTDocController

- (id)initWithDocument:(XTDocument *)doc
{
  self = [super initWithWindowNibName:@"XTDocument"];
  document = doc;

  return self;
}

- (void)windowDidLoad
{
  [super windowDidLoad];

  [self loadViewController:historyView onTab:0];
  [[self window] makeFirstResponder:historyView.historyTable];
  [self loadViewController:stageView onTab:1];
  
  XTRepository *repo = document.repository;

  [repo addObserver:self
         forKeyPath:@"activeTasks"
            options:NSKeyValueObservingOptionNew
            context:nil];
  [historyView setRepo:repo];
  [stageView setRepo:repo];
}

- (void)loadViewController:(NSViewController *)viewController
                     onTab:(NSInteger)tabId
{
  [viewController loadView];
  NSTabViewItem *tabView = [tabs tabViewItemAtIndex:tabId];
  [[viewController view]
      setFrame:NSMakeRect(0, 0,
                          [[viewController view] frame].size.width,
                          [[viewController view] frame].size.height)];
  [tabView setView:[viewController view]];
  NSLog(@"viewController:%@ view:%@", viewController, [viewController view]);
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if ([keyPath isEqualToString:@"activeTasks"]) {
    NSMutableArray *tasks = change[NSKeyValueChangeNewKey];
    if (tasks.count > 0) {
      [activity startAnimation:tasks];
    } else {
      [activity stopAnimation:tasks];
    }
  }
}

- (IBAction)refresh:(id)sender
{
  [document.repository reloadPaths:@[ @".git/refs/", @".git/logs/" ]];
}

- (IBAction)newTag:(id)sender
{
}

- (IBAction)newBranch:(id)sender
{
}

- (IBAction)addRemote:(id)sender
{
}

// Updates the responder chain with the selected tab view's controller.
- (void)tabView:(NSTabView *)tabView
    didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
  NSResponder *nextResponder = [self nextResponder];

  if ([nextResponder isKindOfClass:[NSViewController class]])
    nextResponder = [nextResponder nextResponder];

  NSViewController *controller = nil;

  if ([[tabViewItem identifier] isEqual:@"stage"])
    controller = stageView;
  if ([[tabViewItem identifier] isEqual:@"history"])
    controller = historyView;
  if (controller != nil) {
    [self setNextResponder:controller];
    [controller setNextResponder:nextResponder];
  }
}

@end
