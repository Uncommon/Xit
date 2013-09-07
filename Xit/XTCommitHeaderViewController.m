#import "XTCommitHeaderViewController.h"
#import <WebKit/WebKit.h>
#import "XTRepository+Parsing.h"

@interface XTCommitHeaderViewController ()

@end

@implementation XTCommitHeaderViewController

- (NSURL*)templateURL
{
  return [[NSBundle mainBundle] URLForResource:@"header"
                                 withExtension:@"html"
                                  subdirectory:@"html"];
}

- (NSString*)generateHeaderHTML
{
  NSError *error = nil;
  NSStringEncoding encoding;
  NSString *template = [NSString stringWithContentsOfURL:[self templateURL]
                                            usedEncoding:&encoding
                                                   error:&error];
  NSDictionary *header = nil;
  NSString *message;
  
  [_repository parseCommit:_commitSHA
                intoHeader:&header
                   message:&message
                     files:NULL];

  NSString *authorName = [header objectForKey:XTAuthorNameKey];
  NSString *authorEmail = [header objectForKey:XTAuthorEmailKey];
  NSDate *authorDate = [header objectForKey:XTAuthorDateKey];
  NSString *committerName = [header objectForKey:XTCommitterNameKey];
  NSString *committerEmail = [header objectForKey:XTCommitterEmailKey];
  NSDate *committerDate = [header objectForKey:XTCommitterDateKey];
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

  [formatter setDateStyle:NSDateFormatterMediumStyle];
  [formatter setTimeStyle:NSDateFormatterMediumStyle];

  NSString *authorDateString = [formatter stringFromDate:authorDate];
  NSString *committerDateString = (committerDate == nil) ? @"" :
      [formatter stringFromDate:committerDate];

  if (committerName == nil)
    committerName = @"";
  if (committerEmail == nil)
    committerEmail = @"";

  return [NSString stringWithFormat:template,
      authorName, authorEmail, authorDateString,
      committerName, committerEmail, committerDateString,
      _commitSHA,
      // parents
      message];
}

- (void)loadHeader
{
  NSString *html = [self generateHeaderHTML];

  [[_webView mainFrame] loadHTMLString:html baseURL:[self templateURL]];
}

- (void)setRepository:(XTRepository*)repository commit:(NSString*)commit
{
  _repository = repository;
  _commitSHA = commit;
  [self loadHeader];
}

- (NSUInteger)webView:(WebView*)sender
dragDestinationActionMaskForDraggingInfo:(id<NSDraggingInfo>)draggingInfo
{
  return WebDragDestinationActionNone;
}

@end
