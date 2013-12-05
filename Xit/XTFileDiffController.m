#import "XTFileDiffController.h"
#import <WebKit/WebKit.h>
#import "XTRepository+Parsing.h"

@interface XTFileDiffController ()

@end

@implementation XTFileDiffController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)clear
{
  [[_webView mainFrame] loadHTMLString:@"" baseURL:nil];
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

  [delta enumerateHunksUsingBlock:^(GTDiffHunk *hunk, BOOL *stop) {
    NSError *error = nil;

    [textLines appendString:@"<div class='hunk'>\n"];
    [hunk enumerateLinesInHunk:&error
                    usingBlock:^(GTDiffLine *line, BOOL *stop) {
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

- (BOOL)loadPath:(NSString*)path
          commit:(NSString*)sha
      repository:(XTRepository*)repository
{
  XTDiffDelta *delta =
      [repository diffForFile:path commitSHA:sha parentSHA:nil];

  if (delta != nil) {
    [self loadDiff:delta];
    return YES;
  }
  return NO;
}

@end
