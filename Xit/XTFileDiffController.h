#import "XTWebViewController.h"
#import "XTFileViewController.h"

@class XTRepository;

/**
  Manages a WebView for displaying text file diffs.
 */
@interface XTFileDiffController : XTWebViewController<XTFileContentController>

@end
