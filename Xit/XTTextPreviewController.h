#import "XTWebViewController.h"

@class WebView;
@class XTRepository;

/**
  Manages a WebView for displaying text file contents or diffs.
 */
@interface XTTextPreviewController : XTWebViewController

- (void)loadText:(NSString*)text;
- (BOOL)loadPath:(NSString*)path
          commit:(NSString*)sha
      repository:(XTRepository*)repository;

@end
