#import <Cocoa/Cocoa.h>

@class WebView;
@class XTRepository;

#import <Cocoa/Cocoa.h>
@interface XTTextPreviewController : NSViewController

@property IBOutlet WebView *webView;

- (void)loadText:(NSString*)text;
- (BOOL)loadPath:(NSString*)path
          commit:(NSString*)sha
      repository:(XTRepository*)repository;

@end
