#import <Cocoa/Cocoa.h>

@class WebView;

/**
  Base class for web view controllers, implementing common delegate methods.
**/
@interface XTWebViewController : NSViewController {
  IBOutlet WebView *_webView;
}

@property WebView *webView;

+ (NSString*)htmlTemplate:(NSString*)name;
+ (NSString*)escapeText:(NSString*)text;

@end
