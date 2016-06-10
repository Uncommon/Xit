#import "XTStatusView.h"
#import "XTDocument.h"
#import "XTOutputViewController.h"

NSString *const XTStatusNotification = @"XTStatus";
NSString *const XTStatusTextKey = @"text";
NSString *const XTStatusCommandKey = @"command";
NSString *const XTStatusOutputKey = @"output";

#define kCornerRadius 4

@implementation XTStatusView

+ (void)updateStatus:(NSString *)status
             command:(NSString *)command
              output:(NSString *)output
       forRepository:(XTRepository *)repo
{
  NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];

  assert(repo != nil);
  if (status != nil)
    userInfo[XTStatusTextKey] = status;
  if (command != nil)
    userInfo[XTStatusCommandKey] = command;
  if (output != nil)
    userInfo[XTStatusOutputKey] = output;
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:XTStatusNotification
                      object:repo
                    userInfo:userInfo];
  });
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib
{
  detachedWindow.title =
      [NSString stringWithFormat:detachedWindow.title, self.window.title];
  [detachedWindow setContentSize:(detachedController.view).bounds.size];
  detachedWindow.contentView = detachedController.view;
  [outputController view];  // make sure the view is loaded
}

- (void)viewDidMoveToWindow
{
  NSDocument *doc = ((NSWindowController*)self.window.windowController).document;

  if ([doc isKindOfClass:[XTDocument class]])
    [self setRepo:((XTDocument*)doc).repository];
}

- (void)setRepo:(XTRepository *)newRepo
{
  if (repo != nil)
    [[NSNotificationCenter defaultCenter] removeObserver:self];
  repo = newRepo;

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(updateStatus:)
                                               name:XTStatusNotification
                                             object:repo];
  [[NSNotificationCenter defaultCenter] addObserver:detachedController
                                           selector:@selector(updateStatus:)
                                               name:XTStatusNotification
                                             object:repo];
  [[NSNotificationCenter defaultCenter] addObserver:outputController
                                           selector:@selector(updateStatus:)
                                               name:XTStatusNotification
                                             object:repo];
}

- (void)updateStatus:(NSNotification *)note
{
  NSString *status = note.userInfo[XTStatusTextKey];

  if (status != nil)
    label.stringValue = status;
}

- (IBAction)showOutput:(id)sender
{
  [popover showRelativeToRect:NSZeroRect
                       ofView:sender
                preferredEdge:NSMaxYEdge];
}

@end

@implementation XTStatusView (NSPopoverDelegate)

- (NSWindow *)detachableWindowForPopover:(NSPopover *)pop
{
  [detachedWindow setContentSize:pop.contentSize];
  return detachedWindow;
}

@end
