#import "XTStageViewController.h"
#import "XTDocController.h"
#import "XTFileIndexInfo.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTStagedDataSource.h"
#import "XTStatusView.h"
#import "XTUnstagedDataSource.h"
#import "XTHTML.h"

#import <Cocoa/Cocoa.h>
@interface XTStageViewController ()

@property(readwrite) XTStagedDataSource *stageDS;
@property(readwrite) XTUnstagedDataSource *unstageDS;
@property(readwrite) NSTableView *unstageTable;

@end


@implementation XTStageViewController

@synthesize stageDS;
@synthesize unstageDS;
@synthesize unstageTable;

- (void)awakeFromNib
{
  [stageTable setTarget:self];
  [stageTable setDoubleAction:@selector(stagedDoubleClicked:)];
  [unstageTable setTarget:self];
  [unstageTable setDoubleAction:@selector(unstagedDoubleClicked:)];
}

- (NSString *)nibName
{
  NSLog(@"nibName: %@ (%@)", [super nibName], [self class]);
  return NSStringFromClass([self class]);
}

- (void)setRepo:(XTRepository *)newRepo
{
  repo = newRepo;
  [stageDS setRepo:repo];
  [unstageDS setRepo:repo];
  [repo addObserver:self forKeyPath:@"isWriting" options:0 context:NULL];
}

- (void)reload
{
  [stageDS reload];
  [unstageDS reload];
  [repo executeOffMainThread:^{
    // Do this in the repo queue so it will happen after the reloads.
    [stageTable reloadData];
    [unstageTable reloadData];
  }];
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if ((object == repo) && [keyPath isEqualToString:@"isWriting"])
    [commitButton setEnabled:!repo.isWriting];
}

- (IBAction)commit:(id)sender
{
  XTDocController *doc =
      (XTDocController *)[[[self view] window] windowController];

  if ([sender respondsToSelector:@selector(setEnabled:)])
    [sender setEnabled:NO];
  [repo executeOffMainThread:^{
    NSError *error = NULL;
    void (^outputBlock)(NSString *) = ^(NSString * output) {
      NSString *headSHA = [[repo headSHA] substringToIndex:7];
      NSString *status = [NSString stringWithFormat:@"Committed %@", headSHA];

      [XTStatusView updateStatus:status
                         command:@"commit"
                          output:output
                   forRepository:repo];
    };

    if (![repo commitWithMessage:self.message
                           amend:NO
                     outputBlock:outputBlock
                           error:&error])
      if (error != nil)
        [XTStatusView updateStatus:@"Commit failed"
                           command:@"commit"
                            output:[[error userInfo]
                                       valueForKey:XTErrorOutputKey]
                     forRepository:repo];
    self.message = @"";
    [self reload];
    if ([sender respondsToSelector:@selector(setEnabled:)])
      [sender setEnabled:YES];

    // TODO: Make this automatic
    [doc refresh:nil];
  }];
}

#pragma mark -

- (NSString *)diffForNewFile:(NSString *)file
{
  NSURL *url = [repo.repoURL URLByAppendingPathComponent:file];
  NSStringEncoding encoding;
  NSError *error = nil;
  NSString *contents = [NSString stringWithContentsOfURL:url
                                            usedEncoding:&encoding
                                                   error:&error];
  NSUInteger i = 0, lineCount = 0;

  for (; i < [contents length]; ++i)
    if ([contents characterAtIndex:i] == '\n')
      ++lineCount;
  if ([contents characterAtIndex:i - 1] != '\n')
    ++lineCount;

  NSScanner *scanner = [NSScanner scannerWithString:contents];
  NSString *line;
  NSMutableString *diff =
      [NSMutableString stringWithFormat:@"diff --git /dev/null b/%@\n"
                                         "--- /dev/null\n"
                                         "+++ b/%@\n"
                                         "@@ -0,0 +1,%ld @@\n",
                                         file, file, lineCount];

  [scanner setCharactersToBeSkipped:nil];
  while (![scanner isAtEnd]) {
    if ([scanner scanUpToString:@"\n" intoString:&line]) {
      [diff appendFormat:@"+%@\n", line];
      [scanner scanString:@"\n" intoString:NULL];
    } else if ([scanner scanString:@"\n" intoString:NULL])
      [diff appendString:@"+\n"];
  }
  if ([scanner scanLocation] != [contents length])
    [diff appendFormat:@"+%@\n\\No newline at end of file\n",
        [contents substringFromIndex:[scanner scanLocation] + 1]];
  return diff;
}

- (void)showUnstageFile:(XTFileIndexInfo *)file
{
  [repo executeOffMainThread:^{
    stagedFile = NO;
    actualDiff = [repo diffForUnstagedFile:file.name];
    if ([actualDiff length] == 0)
      actualDiff = [self diffForNewFile:file.name];

    [self showDiff:[XTHTML parseDiff:actualDiff]];
  }];
}

- (void)showStageFile:(XTFileIndexInfo *)file
{
  [repo executeOffMainThread:^{
    stagedFile = YES;
    actualDiff = [repo diffForStagedFile:file.name];

    NSString *diffHTML = [XTHTML parseDiff:actualDiff];
    [self showDiff:diffHTML];
  }];
}

- (void)showDiff:(NSString *)diff
{
  NSString *html = [NSString stringWithFormat:
                        @"<html><head><link rel='stylesheet' type='text/css' "
                         "href='diff.css'/></head><body><div "
                         "id='diffs'>%@</div></body></html>",
                    diff];

  NSBundle *bundle = [NSBundle mainBundle];
  NSURL *htmlURL = [bundle URLForResource:@"html" withExtension:nil];

  dispatch_async(dispatch_get_main_queue(), ^{
    [[web mainFrame] loadHTMLString:html baseURL:htmlURL];
  });
}

- (void)clearDiff
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [[web mainFrame] loadHTMLString:@"" baseURL:nil];
  });
}

- (void)stagedDoubleClicked:(id)sender
{
  NSTableView *tableView = (NSTableView *)sender;
  const NSInteger clickedRow = [tableView clickedRow];

  if (clickedRow == -1)
    return;

  XTFileIndexInfo *item = [stageDS items][clickedRow];

  [repo executeOffMainThread:^{
    if ([repo unstageFile:item.name])
      [self reload];
  }];
}

- (void)unstagedDoubleClicked:(id)sender
{
  NSTableView *tableView = (NSTableView *)sender;
  const NSInteger clickedRow = [tableView clickedRow];

  if (clickedRow == -1)
    return;

  XTFileIndexInfo *item = [unstageDS items][clickedRow];

  [repo executeOffMainThread:^{
    if ([repo stageFile:item.name])
      [self reload];
  }];
}

#pragma mark -

- (void)unstageChunk:(NSInteger)idx
{
  [repo executeOffMainThread:^{
    [repo unstagePatch:[self preparePatch:idx]];
    [self reload];
  }];
}

- (void)stageChunk:(NSInteger)idx
{
  [repo executeOffMainThread:^{
    [repo stagePatch:[self preparePatch:idx]];
    [self reload];
  }];
}

- (void)discardChunk:(NSInteger)idx
{
  [repo executeOffMainThread:^{
    [repo discardPatch:[self preparePatch:idx]];
    [self reload];
  }];
}

#pragma mark -

- (NSString *)preparePatch:(NSInteger)idx
{
  NSArray *components = [actualDiff componentsSeparatedByString:@"\n@@"];
  NSMutableString *patch =
      [NSMutableString stringWithString:components[0]];  // Header

  [patch appendString:@"\n@@"];
  [patch appendString:components[(idx + 1)]];
  [patch appendString:@"\n"];
  return patch;
}

#pragma mark - WebFrameLoadDelegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
  DOMDocument *dom = [[web mainFrame] DOMDocument];
  DOMNodeList *headers =
      [dom getElementsByClassName:@"header"];  // TODO: change class names

  for (int n = 0; n < headers.length; n++) {
    DOMHTMLElement *header = (DOMHTMLElement *)[headers item:n];
    if (stagedFile) {
      [[[header children] item:0] appendChild:
              [self createButtonWithIndex:n title:@"Unstage" fromDOM:dom]];
    } else {
      [[[header children] item:0] appendChild:
              [self createButtonWithIndex:n title:@"Stage" fromDOM:dom]];
      [[[header children] item:0] appendChild:
              [self createButtonWithIndex:n title:@"Discard" fromDOM:dom]];
    }
  }
}

- (DOMHTMLElement *)createButtonWithIndex:(int)index
                                    title:(NSString *)title
                                  fromDOM:(DOMDocument *)dom
{
  DOMHTMLInputElement *button =
      (DOMHTMLInputElement *)[dom createElement:@"input"];

  button.type = @"button";
  button.value = title;
  button.name = [NSString stringWithFormat:@"%d", index];
  [button addEventListener:@"click" listener:self useCapture:YES];
  return button;
}

#pragma mark - DOMEventListener

- (void)handleEvent:(DOMEvent *)event
{
  DOMHTMLInputElement *button = (DOMHTMLInputElement *)event.target;

  NSLog(@"handleEvent: %@ - %@", button.value, button.name);
  if ([button.value isEqualToString:@"Unstage"]) {
    [self unstageChunk:[button.name intValue]];
  } else if ([button.value isEqualToString:@"Stage"]) {
    [self stageChunk:[button.name intValue]];
  } else if ([button.value isEqualToString:@"Discard"]) {
    [self discardChunk:[button.name intValue]];
  }
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSTableView *table = (NSTableView *)aNotification.object;

  if (table.numberOfSelectedRows > 0) {
    if ([table isEqualTo:stageTable]) {
      [unstageTable deselectAll:nil];
      XTFileIndexInfo *item = [stageDS items][table.selectedRow];
      [self showStageFile:item];
    } else if ([table isEqualTo:unstageTable]) {
      [stageTable deselectAll:nil];
      XTFileIndexInfo *item = [unstageDS items][table.selectedRow];
      [self showUnstageFile:item];
    }
  } else {
    [self clearDiff];
  }
}

@end
