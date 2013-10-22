#import "XTWebViewController.h"

@class WebView;
@class XTRepository;

@interface XTTextPreviewController : XTWebViewController

- (void)loadText:(NSString*)text;
- (BOOL)loadPath:(NSString*)path
          commit:(NSString*)sha
      repository:(XTRepository*)repository;

@end
