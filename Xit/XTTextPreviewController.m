#import "XTTextPreviewController.h"

#import <WebKit/WebKit.h>

#import "XTRepository+Parsing.h"

@implementation XTTextPreviewController

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self != nil) {
    // Initialization code here.
  }
  
  return self;
}

+ (NSString*)htmlTemplate:(NSString*)name
{
  NSURL *htmlURL = [[NSBundle mainBundle]
      URLForResource:name withExtension:@"html" subdirectory:@"html"];
  NSStringEncoding encoding;
  NSError *error = nil;
  NSString *htmlTemplate = [NSString stringWithContentsOfURL:htmlURL
                                                usedEncoding:&encoding
                                                       error:&error];

  NSAssert(htmlTemplate != nil, @"Couldn't load text.html");
  return htmlTemplate;
}

+ (NSString*)escapeText:(NSString*)text
{
  return (NSString*)CFBridgingRelease(
      CFXMLCreateStringByEscapingEntities(
          kCFAllocatorDefault, (__bridge CFStringRef)text, NULL));
}

- (void)loadText:(NSString*)text
{
  NSMutableString *textLines = [NSMutableString string];

  [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
    [textLines appendFormat:@"<div>%@</div>\n",
                            [[self class] escapeText:line]];
  }];

  NSString *htmlTemplate = [[self class] htmlTemplate:@"text"];
  NSString *html = [NSString stringWithFormat:htmlTemplate, textLines];
  NSURL *baseURL = [[NSBundle mainBundle]
      URLForResource:@"html" withExtension:nil];

  [[_webView mainFrame] loadHTMLString:html baseURL:baseURL];
}

+ (void)appendDiffLine:(NSString*)text
                    to:(NSMutableString*)lines
               oldLine:(NSUInteger)oldLine
               newLine:(NSUInteger)newLine
{
  NSString *numberFormat = @"%lu";
  NSString *class = @"pln";
  NSString *oldLineText = @"";
  NSString *newLineText = @"";

  if (oldLine == -1)
    class = @"add";
  else
    oldLineText =
        [NSString stringWithFormat:numberFormat, (unsigned long)oldLine];
  if (newLine == -1)
    class = @"del";
  else
    newLineText =
        [NSString stringWithFormat:numberFormat, (unsigned long)newLine];
  [lines appendFormat:
      @"<div class='%@'>"
       "<span class='old'>%@</span>"
       "<span class='new'>%@</span>"
       "<span class='text'>%@</span>"
       "</div>\n",
       class, oldLineText, newLineText,
       [[self class] escapeText:text]];
}

- (void)loadDiff:(XTDiffDelta*)delta
{
  NSString *htmlTemplate = [[self class] htmlTemplate:@"diff"];
  NSMutableString *textLines = [NSMutableString string];

  [delta enumerateHunksWithBlock:^(GTDiffHunk *hunk, BOOL *stop) {
    [textLines appendString:@"<div class='hunk'>\n"];
    [hunk enumerateLinesInHunkUsingBlock:^(GTDiffLine *line, BOOL *stop) {
      [[self class] appendDiffLine:line.content
                                to:textLines
                           oldLine:line.oldLineNumber
                           newLine:line.newLineNumber];
    }];
    [textLines appendString:@"</div>\n"];
  }];

  NSString *html = [NSString stringWithFormat:htmlTemplate, textLines];
  NSURL *baseURL = [[NSBundle mainBundle]
      URLForResource:@"html" withExtension:nil];

  [[_webView mainFrame] loadHTMLString:html baseURL:baseURL];
}

- (BOOL)isFileChanged:(NSString*)path inRepository:(XTRepository*)repo
{
  NSArray *changes = [repo changesForRef:repo.selectedCommit parent:nil];

  for (XTFileChange *change in changes)
    if ([change.path isEqualToString:path])
      return YES;
  return NO;
}

- (BOOL)loadPath:(NSString*)path
          commit:(NSString*)sha
      repository:(XTRepository*)repository
{
  if ([self isFileChanged:path inRepository:repository]) {
    XTDiffDelta *delta =
        [repository diffForFile:path commitSHA:sha parentSHA:nil];

    if (delta != nil) {
      [self loadDiff:delta];
      return YES;
    }
    return NO;
  } else {
    NSData *data = [repository contentsOfFile:path atCommit:sha];
    NSString *text = [[NSString alloc]
        initWithData:data encoding:NSUTF8StringEncoding];

    // TODO: Use TECSniffTextEncoding to detect encoding.
    if (text == nil) {
      text = [[NSString alloc]
          initWithData:data encoding:NSUTF16StringEncoding];
      if (text == nil)
        return NO;
    }
    [self loadText:text];
    return YES;
  }
}

- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame
{
  NSScrollView *scrollView = [[[[_webView mainFrame] frameView]
      documentView] enclosingScrollView];

  [scrollView setHasHorizontalScroller:NO];
  [scrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
  [scrollView setBackgroundColor:[NSColor colorWithDeviceWhite:0.8 alpha:1.0]];
}

@end
