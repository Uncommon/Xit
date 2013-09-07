#import <Cocoa/Cocoa.h>

@class WebView;
@class XTRepository;
@protocol WebUIDelegate;

@interface XTCommitHeaderViewController : NSViewController
{
  XTRepository *_repository;
  NSString *_commitSHA;
}

@property IBOutlet WebView *webView;

- (void)setRepository:(XTRepository*)repository commit:(NSString*)commit;

@end
