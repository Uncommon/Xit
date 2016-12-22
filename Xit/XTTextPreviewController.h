#import "XTWebViewController.h"
#import "XTFileViewController.h"

@class WebView;
@class XTRepository;

/**
  Manages a WebView for displaying text file contents or diffs.
 */
@interface XTTextPreviewController : XTWebViewController
    <XTFileContentController, TabWidthVariable>

@property NSUInteger tabWidth;

- (void)loadText:(nullable NSString*)text;

@end
