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
  [[NSNotificationCenter defaultCenter] removeObserver:self];
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
  __weak XTFileListDataSourceBase *weakSelf = self;
  
  _winController = winController;
  [[NSNotificationCenter defaultCenter]
      addObserverForName:XTSelectedModelChangedNotification
                  object:winController
                   queue:nil
              usingBlock:^(NSNotification * _Nonnull note) {
    [weakSelf reload];
    [weakSelf updateStagingView];
  }];
}

- (void)updateStagingView
{
  NSTableColumn *unstagedColumn =
      [self.outlineView tableColumnWithIdentifier:@"unstaged"];

  unstagedColumn.hidden = !self.winController.selectedModel.hasUnstaged;
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
