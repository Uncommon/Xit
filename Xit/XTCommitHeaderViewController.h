#import "XTWebViewController.h"

@class XTRepository;

@interface XTCommitHeaderViewController : XTWebViewController
{
  NSString *_commitSHA;
  BOOL _expanded;
}

@property XTRepository *repository;
@property NSString *commitSHA;

+ (NSDateFormatter*)dateFormatter;
- (void)setRepository:(XTRepository*)repository;
- (void)loadHeader;

@end
