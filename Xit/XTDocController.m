#import "XTDocController.h"
#import "XTDocument.h"
#import "XTHistoryViewController.h"
#import "XTRepository.h"
#import "XTStageViewController.h"
#import "XTStatusView.h"

@interface XTDocController (Private)

- (void)loadViewController:(NSViewController *)viewController onTab:(NSInteger)tabId;

@end

@implementation XTDocController

- (id)initWithDocument:(XTDocument *)doc {
    self = [super initWithWindowNibName:@"XTDocument"];

    document = doc;

    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    [self loadViewController:historyView onTab:0];
    [self loadViewController:stageView onTab:1];

    XTRepository *repo = document.repository;

    [repo addObserver:self forKeyPath:@"activeTasks" options:NSKeyValueObservingOptionNew context:nil];
    [historyView setRepo:repo];
    [stageView setRepo:repo];
    [statusView setRepo:repo];
}

- (void)loadViewController:(NSViewController *)viewController onTab:(NSInteger)tabId {
    [viewController loadView];
    NSTabViewItem *tabView = [tabs tabViewItemAtIndex:tabId];
    [[viewController view] setFrame:NSMakeRect(0, 0, [[viewController view] frame].size.width, [[viewController view] frame].size.height)];
    [tabView setView:[viewController view]];
    NSLog(@"viewController:%@ view:%@", viewController, [viewController view]);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"activeTasks"]) {
        NSMutableArray *tasks = [change objectForKey:NSKeyValueChangeNewKey];
        if (tasks.count > 0) {
            [activity startAnimation:tasks];
        } else {
            [activity stopAnimation:tasks];
        }
    }
}

- (IBAction)refresh:(id)sender {
    [document.repository reloadPaths:[NSArray arrayWithObjects:@".git/refs/", @".git/logs/", nil]];
}

- (IBAction)newTag:(id)sender {
}

- (IBAction)newBranch:(id)sender {
}

- (IBAction)addRemote:(id)sender {
}

// This works around an Interface Builder/Xcode bug. If you make a toolbar
// item by dragging in a Custom View, the view's -drawRect never gets called.
// Instead the xib has a plain toolbar item that is modified at runtime.
- (void)toolbarWillAddItem:(NSNotification *)notification {
    NSToolbarItem *item = (NSToolbarItem *)[[notification userInfo] objectForKey:@"item"];

    if ([[item itemIdentifier] isEqualToString:@"xit.status"]) {
        if (statusView == nil)
            [NSBundle loadNibNamed:@"XTStatusView" owner:self];
        [item setView:statusView];
    }
}

// Updates the responder chain with the selected tab view's controller.
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
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
