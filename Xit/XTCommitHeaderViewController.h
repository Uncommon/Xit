#import <Cocoa/Cocoa.h>

@class WebView;
@class XTRepository;
@protocol WebUIDelegate;

@interface XTCommitHeaderViewController : NSViewController
{
  NSString *_commitSHA;
}

@property XTRepository *repository;
@property NSString *commitSHA;
@property IBOutlet WebView *webView;

+ (NSDateFormatter*)dateFormatter;
- (void)setRepository:(XTRepository*)repository;
- (void)loadHeader;

@end
