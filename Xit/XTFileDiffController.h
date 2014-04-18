#import "XTWebViewController.h"

@class XTRepository;

/**
  Manages a WebView for displaying text file diffs.
 */
@interface XTFileDiffController : XTWebViewController

- (void)clear;
- (BOOL)loadPath:(NSString*)path
          commit:(NSString*)sha
      repository:(XTRepository*)repository;

@end
