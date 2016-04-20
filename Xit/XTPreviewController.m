#import "XTPreviewController.h"
#import "XTPreviewItem.h"
#import <Quartz/Quartz.h>

@interface XTPreviewController ()

@property QLPreviewView *view;

@end


@implementation XTPreviewController

@dynamic view;

- (void)clear
{
  self.view.previewItem = nil;
}

- (void)loadPath:(NSString*)path
          commit:(NSString*)sha
      repository:(XTRepository*)repository
{
  [self.view setHidden:NO];
  
  XTPreviewItem *previewItem = (XTPreviewItem *)self.view.previewItem;
  
  if (previewItem == nil) {
    previewItem = [[XTPreviewItem alloc] init];
    previewItem.repo = repository;
    self.view.previewItem = previewItem;
  }
  
  previewItem.commitSHA = sha;
  previewItem.path = path;
  [self.view refreshPreviewItem];
}

- (void)loadUnstagedPath:(NSString*)path
              repository:(XTRepository*)repository
{
  
}

- (void)loadStagedPath:(NSString*)path
            repository:(XTRepository*)repository
{
  
}

@end
