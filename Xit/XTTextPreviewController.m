#import "XTTextPreviewController.h"

#import <WebKit/WebKit.h>

#import "XTRepository+Parsing.h"
#import "Xit-Swift.h"

@implementation XTTextPreviewController

- (instancetype)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self != nil) {
    // Initialization code here.
  }
  
  return self;
}

- (void)clear
{
  [_webView.mainFrame loadHTMLString:@"" baseURL:nil];
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

  [_webView.mainFrame loadHTMLString:html baseURL:[[self class] baseURL]];
}

- (void)loadData:(NSData*)data
{
  if (data == nil)
    return;

  NSString *text = [[NSString alloc]
                    initWithData:data encoding:NSUTF8StringEncoding];
  
  if (text == nil)
    text = [[NSString alloc]
            initWithData:data encoding:NSUTF16StringEncoding];
  
  [self loadText:text];
}

- (BOOL)isFileChanged:(NSString*)path inRepository:(XTRepository*)repo
{
  XTWindowController *controller = self.view.window.windowController;
  NSArray *changes =
      [repo changesForRef:controller.selectedModel.shaToSelect parent:nil];

  for (XTFileChange *change in changes)
    if ([change.path isEqualToString:path])
      return YES;
  return NO;
}

- (void)loadPath:(NSString *)path
           model:(id<XTFileChangesModel>)model
          staged:(BOOL)staged
{
  [self loadData:[model dataForFile:path staged:staged]];
}

- (void)loadUnstagedPath:(NSString*)path
              repository:(XTRepository*)repository
{
  NSURL *url = [repository.repoURL URLByAppendingPathComponent:path];
  
  [self loadData:[NSData dataWithContentsOfURL:url]];
}

- (void)loadStagedPath:(NSString*)path
            repository:(XTRepository*)repository
{
  NSError *error = nil;
  
  [self loadData:[repository contentsOfStagedFile:path error:&error]];
}

@end
