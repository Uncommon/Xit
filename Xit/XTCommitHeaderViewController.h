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

+ (NSDateFormatter*)dateFormatter;
- (void)setRepository:(XTRepository*)repository commit:(NSString*)commit;
- (void)loadHeader;

@end
