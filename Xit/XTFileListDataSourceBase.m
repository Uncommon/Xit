#import "XTFileListDataSourceBase.h"
#import "XTConstants.h"
#import "XTDocController.h"
#import "XTFileViewController.h"
#import "XTRepository.h"
#import <objc/runtime.h>

#define XTAssertOverride() \
  NSAssert(false, @"%s must be overridden", sel_getName(_cmd))


@implementation XTFileListDataSourceBase

@synthesize controller = _controller;

- (void)dealloc
{
  [self.docController removeObserver:self forKeyPath:@"selectedCommitSHA"];
}

- (void)reload
{
  XTAssertOverride();
}

- (BOOL)isHierarchical
{
  XTAssertOverride();
  return NO;
}

- (void)setRepository:(XTRepository*)repository
{
  _repository = repository;
  [self reload];
}

- (XTFileViewController*)controller
{
  return _controller;
}

- (void)setController:(XTFileViewController*)controller
{
  @synchronized (self) {
    _controller = controller;
    [controller addObserver:self
                 forKeyPath:@"inStagingView"
                    options:nil
                    context:NULL];
  }
}

- (void)setDocController:(XTDocController *)docController
{
  _docController = docController;
  [_docController addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(selectedCommitSHA))
                      options:NSKeyValueObservingOptionNew
                      context:nil];
}

- (void)updateStagingView
{
  NSTableColumn *unstagedColumn =
      [self.outlineView tableColumnWithIdentifier:@"unstaged"];

  unstagedColumn.hidden = !self.controller.inStagingView;
  // update the column highliht
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
  if ([keyPath isEqualToString:@"selectedCommitSHA"])
    [self reload];
  else if ([keyPath isEqualToString:@"inStagingView"])
    [self updateStagingView];
}

- (XTFileChange*)fileChangeAtRow:(NSInteger)row
{
  return nil;
}

- (NSString*)pathForItem:(id)item
{
  XTAssertOverride();
  return nil;
}

+ (XitChange)transformDisplayChange:(XitChange)change
{
  return (change == XitChangeUnmodified) ? XitChangeMixed : change;
}

- (XitChange)changeForItem:(id)item
{
  XTAssertOverride();
  return XitChangeUnmodified;
}

- (XitChange)unstagedChangeForItem:(id)item
{
  XTAssertOverride();
  return XitChangeUnmodified;
}

@end


@implementation XTFileCellView

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
  [super setBackgroundStyle:backgroundStyle];
  if (backgroundStyle == NSBackgroundStyleDark)
    self.textField.textColor = [NSColor textColor];
  else if (self.change == XitChangeDeleted)
    self.textField.textColor = [NSColor disabledControlTextColor];
}

@end


@implementation XTTableButtonView

@end
