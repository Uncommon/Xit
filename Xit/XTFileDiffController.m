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
  NSError *error = nil;
  GTDiffPatch *patch = [delta generatePatch:&error];

  if (error != nil) {
    // TODO: report error
    return;
  }

  [patch enumerateHunksUsingBlock:^(GTDiffHunk *hunk, BOOL *stop) {
    NSError *hunkError = nil;

    [textLines appendString:@"<div class='hunk'>\n"];
    [hunk enumerateLinesInHunk:&hunkError
                    usingBlock:^(GTDiffLine *line, BOOL *stop) {
      [[self class] appendDiffLine:line.content
                                to:textLines
                           oldLine:line.oldLineNumber
                           newLine:line.newLineNumber];
    }];
    if (hunkError != nil) {
      // TODO: report error
      *stop = YES;
      return;
    }
    [textLines appendString:@"</div>\n"];
  }];

  NSString *html = [NSString stringWithFormat:htmlTemplate, textLines];

  [[_webView mainFrame] loadHTMLString:html baseURL:[[self class] baseURL]];
}

- (BOOL)loadPath:(NSString*)path
          commit:(NSString*)sha
      repository:(XTRepository*)repository
{
  if ([path length] == 0) {
    [self loadNotice:@"No selection"];
    return YES;
  }

  XTDiffDelta *delta =
      [repository diffForFile:path commitSHA:sha parentSHA:nil];

  if (delta == nil) {
    [self loadNotice:@"No changes for this selection"];
    return YES;
  } else {
    [self loadDiff:delta];
    return YES;
  }
  return NO;
}

@end
