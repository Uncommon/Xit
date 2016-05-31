#import "XTDocController.h"
#import "XTConstants.h"
#import "XTDocument.h"
#import "XTHistoryViewController.h"
#import "XTRepository.h"
#import "XTStatusView.h"

@implementation XTDocController

- (id)initWithDocument:(XTDocument *)doc
{
  self = [super initWithWindowNibName:@"XTDocument"];
  _xtDocument = doc;

  return self;
}

- (void)windowDidLoad
{
  [super windowDidLoad];

  self.window.contentViewController = _historyView;
  [[self window] makeFirstResponder:_historyView.historyTable];
  
  XTRepository *repo = _xtDocument.repository;

  [repo addObserver:self
         forKeyPath:@"activeTasks"
            options:NSKeyValueObservingOptionNew
            context:nil];
  [_historyView windowDidLoad];
  [_historyView setRepo:repo];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if ([keyPath isEqualToString:@"activeTasks"]) {
    NSMutableArray *tasks = change[NSKeyValueChangeNewKey];
    if (tasks.count > 0) {
      [_activity startAnimation:tasks];
    } else {
      [_activity stopAnimation:tasks];
    }
  }
}

- (BOOL)inStagingView
{
  return [self.selectedCommitSHA isEqualToString:XTStagingSHA];
}

- (IBAction)refresh:(id)sender
{
  [[NSNotificationCenter defaultCenter]
      postNotificationName:XTRepositoryChangedNotification
                    object:_xtDocument.repository];
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

@end
