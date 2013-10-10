#import <Cocoa/Cocoa.h>

@class WebView;

// Base class for web view controllers, implementing common delegate methods.
@interface XTWebViewController : NSViewController

@property IBOutlet WebView *webView;

@end
