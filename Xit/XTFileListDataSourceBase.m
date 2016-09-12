#import "XTFileListDataSourceBase.h"
#import "XTConstants.h"
#import "XTFileViewController.h"
#import "XTRepository.h"
#import "Xit-Swift.h"
#import <objc/runtime.h>


@implementation XTFileListDataSourceBase

@synthesize controller = _controller;

- (void)dealloc
{
  [self.winController removeObserver:self forKeyPath:@"selectedModel"];
}

- (void)reload
{
  // Subclasses must override
}

- (void)setRepository:(XTRepository*)repository
{
  _repository = repository;
  [self reload];
}

- (void)setWinController:(XTWindowController*)winController
{
  _winController = winController;
  [_winController addObserver:self
                   forKeyPath:@"selectedModel"
                      options:NSKeyValueObservingOptionNew
                      context:nil];
}

- (void)updateStagingView
{
  NSTableColumn *unstagedColumn =
      [self.outlineView tableColumnWithIdentifier:@"unstaged"];

  unstagedColumn.hidden = !self.winController.selectedModel.hasUnstaged;
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
  if ([keyPath isEqualToString:@"selectedModel"]) {
    [self reload];
    [self updateStagingView];
  }
}

+ (XitChange)transformDisplayChange:(XitChange)change
{
  return (change == XitChangeUnmodified) ? XitChangeMixed : change;
}

@end


@implementation XTFileCellView

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
  super.backgroundStyle = backgroundStyle;
  if (backgroundStyle == NSBackgroundStyleDark)
    self.textField.textColor = [NSColor textColor];
  else if (self.change == XitChangeDeleted)
    self.textField.textColor = [NSColor disabledControlTextColor];
}

@end


@implementation XTTableButtonView

@end
