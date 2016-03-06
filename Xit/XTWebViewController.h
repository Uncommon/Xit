#import <Cocoa/Cocoa.h>

@class WebFrame;
@class WebView;

/**
  Base class for web view controllers, implementing common delegate methods.
**/
@interface XTWebViewController : NSViewController {
  IBOutlet WebView *_webView;
}

@property WebView *webView;

+ (NSString*)htmlTemplate:(NSString*)name;
+ (NSURL*)baseURL;
+ (NSString*)escapeText:(NSString*)text;

- (void)loadNotice:(NSString*)text;
- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame;

@end
