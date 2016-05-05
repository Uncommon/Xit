#import "XTPreviewController.h"
#import "XTConstants.h"
#import "XTPreviewItem.h"
#import "XTRepository.h"
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
  
  if (![previewItem isKindOfClass:[XTPreviewItem class]]) {
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
  [self.view setHidden:NO];
  
  NSURL *fileURL = [repository.repoURL URLByAppendingPathComponent:path];
  
  self.view.previewItem = fileURL;
}

- (void)loadStagedPath:(NSString*)path
            repository:(XTRepository*)repository
{
  [self loadPath:path commit:XTStagingSHA repository:repository];
}

@end
