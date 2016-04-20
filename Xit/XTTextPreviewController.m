#import "XTTextPreviewController.h"

#import <WebKit/WebKit.h>

#import "XTDocController.h"
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

- (void)clear
{
  [[_webView mainFrame] loadHTMLString:@"" baseURL:nil];
}

- (void)loadText:(NSString*)text
{
  if (text == nil)
    text = @"";

  NSMutableString *textLines = [NSMutableString string];

  [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
    [textLines appendFormat:@"<div>%@</div>\n",
                            [[self class] escapeText:line]];
  }];

  NSString *htmlTemplate = [[self class] htmlTemplate:@"text"];
  NSString *html = [NSString stringWithFormat:htmlTemplate, textLines];

  [[_webView mainFrame] loadHTMLString:html baseURL:[[self class] baseURL]];
}

- (BOOL)isFileChanged:(NSString*)path inRepository:(XTRepository*)repo
{
  XTDocController *controller = self.view.window.windowController;
  NSAssert([controller isKindOfClass:[XTDocController class]], @"");
  NSArray *changes =
      [repo changesForRef:controller.selectedCommitSHA parent:nil];

  for (XTFileChange *change in changes)
    if ([change.path isEqualToString:path])
      return YES;
  return NO;
}

- (void)loadPath:(NSString*)path
          commit:(NSString*)sha
      repository:(XTRepository*)repository
{
  NSData *data = [repository contentsOfFile:path atCommit:sha];
  NSString *text = [[NSString alloc]
      initWithData:data encoding:NSUTF8StringEncoding];

  // TODO: Use TECSniffTextEncoding to detect encoding.
  if (text == nil)
    text = [[NSString alloc]
        initWithData:data encoding:NSUTF16StringEncoding];
  
  [self loadText:text];
}


- (void)loadUnstagedPath:(NSString*)path
              repository:(XTRepository*)repository
{
  // show file on disk
}

- (void)loadStagedPath:(NSString*)path
            repository:(XTRepository*)repository
{
  // show file from index
}

@end
