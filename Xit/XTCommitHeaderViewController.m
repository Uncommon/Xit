#import "XTCommitHeaderViewController.h"
#import <WebKit/WebKit.h>
#import <ObjectiveGit/ObjectiveGit.h>
#import "XTConstants.h"
#import "XTRepository+Parsing.h"
#import "Xit-Swift.h"

NSString *XTHeaderResizedNotificaiton = @"XTHeaderResizedNotificaiton";
NSString *XTHeaderHeightKey = @"height";

@interface XTCommitHeaderViewController ()

@property NSArray *parents;

@end

@implementation XTCommitHeaderViewController

+ (NSDateFormatter*)dateFormatter
{
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

  formatter.dateStyle = NSDateFormatterMediumStyle;
  formatter.timeStyle = NSDateFormatterMediumStyle;
  return formatter;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector
{
  if (selector == @selector(selectSHA:))
    return NO;
  if (selector == @selector(headerToggled))
    return NO;
  return YES;
}

+ (NSString*)webScriptNameForSelector:(SEL)selector
{
  if (selector == @selector(selectSHA:))
    return @"selectSHA";
  return @"";
}

- (NSURL*)templateURL
{
  return [[NSBundle mainBundle] URLForResource:@"header"
                                 withExtension:@"html"
                                  subdirectory:@"html"];
}

- (NSString*)generateHeaderHTML:(XTCommit*)commit
{
  if ((_commitSHA == nil) || [_commitSHA isEqualToString:XTStagingSHA])
    return @"";

  NSError *error = nil;
  NSStringEncoding encoding;
  NSString *template = [NSString stringWithContentsOfURL:[self templateURL]
                                            usedEncoding:&encoding
                                                   error:&error];
  NSString *message = commit.message;
  NSString *authorName = commit.authorName;
  NSString *authorEmail = commit.authorEmail;
  NSDate *authorDate = commit.authorDate;
  NSString *committerName = commit.committerName;
  NSString *committerEmail = commit.committerEmail;
  NSDate *committerDate = commit.commitDate;
  NSDateFormatter *formatter = [[self class] dateFormatter];
  NSString *authorDateString = [formatter stringFromDate:authorDate];
  NSString *committerDateString = (committerDate == nil) ? @"" :
      [formatter stringFromDate:committerDate];

  if (committerName == nil)
    committerName = @"";
  if (committerEmail == nil)
    committerEmail = @"";

  self.parents = commit.parentSHAs;
  
  NSMutableString *parents = [NSMutableString string];
  GTRepository *gtRepo = _repository.gtRepo;
  
  for (NSString *parentSHA in commit.parentSHAs) {
    GTCommit *parentCommit =
        [gtRepo lookUpObjectBySHA:parentSHA error:&error];
    
    if (parentCommit == nil)
      continue;
    
    NSString *summary = parentCommit.messageSummary;
    CFStringRef cfEncodedSummary =
        CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault,
                                            (__bridge CFStringRef)summary,
                                            NULL);
    NSString *encodedSummary = (NSString*)CFBridgingRelease(cfEncodedSummary);
    NSString *parentText = [NSString stringWithFormat:@"%@ %@",
                            [parentSHA substringToIndex:6], encodedSummary];
    
    [parents appendFormat:@"<div><span class=\"parent\" "
                           "onclick=\"window.controller.selectSHA('%@')\">"
                           "%@</span></div>",
                           parentSHA, parentText];
  }

  message = [message stringByTrimmingCharactersInSet:
      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
  return [NSString stringWithFormat:template,
      authorName, authorEmail, authorDateString,
      committerName, committerEmail, committerDateString,
      _commitSHA,
      parents,
      message];
}

- (void)loadHeader
{
  id result = [_webView.windowScriptObject
      callWebScriptMethod:@"isCollapsed" withArguments:@[]];

  if ([result respondsToSelector:@selector(boolValue)])
    _expanded = ![result boolValue];

  XTCommit *commit = [[XTCommit alloc] initWithSha:_commitSHA
                                        repository:_repository];
  NSString *html = [self generateHeaderHTML:commit];

  [_webView.mainFrame loadHTMLString:html baseURL:[self templateURL]];
}

- (NSString*)commitSHA
{
  return _commitSHA;
}

- (void)setCommitSHA:(NSString *)sha
{
  _commitSHA = sha;
  [self loadHeader];
}

- (CGFloat)headerHeight
{
  const NSRect savedFrame = _webView.frame;

  _webView.frame = NSMakeRect(0, 0, savedFrame.size.width, 1);

  const CGFloat result =
      _webView.mainFrame.frameView.documentView.frame.size.height;

  _webView.frame = savedFrame;
  return result;
}

#pragma mark - WebView delegate methods

- (NSUInteger)webView:(WebView*)sender
dragDestinationActionMaskForDraggingInfo:(id<NSDraggingInfo>)draggingInfo
{
  return WebDragDestinationActionNone;
}

- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame
{
  [super webView:sender didFinishLoadForFrame:frame];

  if (!_expanded)
    [_webView.windowScriptObject callWebScriptMethod:@"disclosure"
                                       withArguments:@[ @(NO), @(YES) ]];
}

#pragma mark - Web scripting

- (void)selectSHA:(NSString*)sha
{
  self.winController.selectedModel =
      [[XTCommitChanges alloc] initWithRepository:self.repository sha:sha];
}

- (void)headerToggled
{
  const CGFloat newHeight = [self headerHeight];

  [[NSNotificationCenter defaultCenter]
      postNotificationName:XTHeaderResizedNotificaiton
      object:self
      userInfo:@{ XTHeaderHeightKey: @(newHeight) }];
}

@end
