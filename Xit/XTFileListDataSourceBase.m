#import "XTFileListDataSourceBase.h"
#import "XTConstants.h"
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
  
  __weak XTFileListDataSourceBase *weakSelf = self;
  
  [[NSNotificationCenter defaultCenter]
      addObserverForName:XTRepositoryWorkspaceChangedNotification
                  object:repository
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification * _Nonnull note) {
    [weakSelf workspaceChanged:note.userInfo[XTPathsKey]];
  }];
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

- (void)workspaceChanged:(NSArray<NSString*>*)paths
{
  if ([(NSObject*)_winController.selectedModel
          isKindOfClass:[XTStagingChanges class]])
    [self reload];
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
