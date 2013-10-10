#import "XTTextPreviewController.h"

#import <WebKit/WebKit.h>

#import "XTRepository.h"

@implementation XTTextPreviewController

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self != nil) {
    // Initialization code here.
  }
  
  return self;
}

- (void)loadText:(NSString*)text
{
  NSMutableString *textLines = [NSMutableString string];

  [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
    NSString *escaped = (NSString*)CFBridgingRelease(
        CFXMLCreateStringByEscapingEntities(
            kCFAllocatorDefault, (__bridge CFStringRef)line, NULL));

    [textLines appendFormat:@"<div>%@</div>\n", escaped];
  }];

  NSURL *htmlURL = [[NSBundle mainBundle]
      URLForResource:@"text" withExtension:@"html" subdirectory:@"html"];
  NSStringEncoding encoding;
  NSError *error = nil;
  NSString *htmlTemplate = [NSString stringWithContentsOfURL:htmlURL
                                                usedEncoding:&encoding
                                                       error:&error];

  NSAssert(htmlTemplate != nil, @"Couldn't load text.html");

  NSString *html = [NSString stringWithFormat:htmlTemplate, textLines];
  NSURL *baseURL = [[NSBundle mainBundle]
      URLForResource:@"html" withExtension:nil];

  [[self.webView mainFrame] loadHTMLString:html baseURL:baseURL];
}

- (BOOL)loadPath:(NSString*)path
          commit:(NSString*)sha
      repository:(XTRepository*)repository
{
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

- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame
{
  NSScrollView *scrollView = [[[[self.webView mainFrame] frameView]
      documentView] enclosingScrollView];

  [scrollView setHasHorizontalScroller:NO];
  [scrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
  [scrollView setBackgroundColor:[NSColor colorWithDeviceWhite:0.8 alpha:1.0]];
}

@end
