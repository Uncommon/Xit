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

- (void)loadPath:(NSString *)path
           model:(id<XTFileChangesModel>)model
          staged:(BOOL)staged
{
  if (!staged) {
    self.view.previewItem = [model unstagedFileURL:path];
  }
  else {
    XTPreviewItem *previewItem = (XTPreviewItem*)self.view.previewItem;
    
    if (![previewItem isKindOfClass:[XTPreviewItem class]]) {
      previewItem = [[XTPreviewItem alloc] init];
      self.view.previewItem = previewItem;
    }
    
    previewItem.model = model;
    previewItem.path = path;
    [self.view refreshPreviewItem];
  }
}

- (BOOL) canSetWhitespace
{
  return NO;
}

- (BOOL) canSetTabWidth
{
  return NO;
}

@end
