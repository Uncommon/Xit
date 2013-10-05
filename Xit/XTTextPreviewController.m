#import "XTTextPreviewController.h"

#import <WebKit/WebKit.h>

#import "XTRepository.h"

@interface XTTextPreviewController ()

@end

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
    [textLines appendFormat:@"<div>%@</div>\n", line];
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

@end
