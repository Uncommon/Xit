#import "XTStageViewController.h"
#import "XTDocController.h"
#import "XTFileIndexInfo.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTStagedDataSource.h"
#import "XTStatusView.h"
#import "XTUnstagedDataSource.h"
#import "XTHTML.h"

@interface XTStageViewController ()

@property(readwrite) XTStagedDataSource *stageDS;
@property(readwrite) XTUnstagedDataSource *unstageDS;
@property(readwrite) NSTableView *unstageTable;

@end


@implementation XTStageViewController

- (void)awakeFromNib
{
  [_stageTable setTarget:self];
  [_stageTable setDoubleAction:@selector(stagedDoubleClicked:)];
  [_unstageTable setTarget:self];
  [_unstageTable setDoubleAction:@selector(unstagedDoubleClicked:)];
}

- (NSString *)nibName
{
  NSLog(@"nibName: %@ (%@)", [super nibName], [self class]);
  return NSStringFromClass([self class]);
}

- (void)setRepo:(XTRepository *)newRepo
{
  _repo = newRepo;
	[_stageDS setRepo:_repo];
	[_unstageDS setRepo:_repo];
  [_repo addObserver:self forKeyPath:@"isWriting" options:0 context:NULL];
}

- (void)reload
{
  [_stageDS reload];
  [_unstageDS reload];
  [_repo executeOffMainThread:^{
	  // Do this in the _repo queue so it will happen after the reloads.
	  [_stageTable reloadData];
	  [_unstageTable reloadData];
  }];
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if ((object == _repo) && [keyPath isEqualToString:@"isWriting"])
    [_commitButton setEnabled:!_repo.isWriting];
}

- (IBAction)commit:(id)sender
{
  XTDocController *doc =
      (XTDocController *)[[[self view] window] windowController];

  if ([sender respondsToSelector:@selector(setEnabled:)])
    [sender setEnabled:NO];
  [_repo executeOffMainThread:^{
	  NSError *error = NULL;
	  void (^outputBlock)(NSString *) = ^(NSString *output) {
		  NSString *headSHA = [[_repo headSHA] substringToIndex:7];
		  NSString *status = [NSString stringWithFormat:@"Committed %@", headSHA];

		  [XTStatusView updateStatus:status
                         command:@"commit"
                          output:output
                   forRepository:_repo];
	  };

	  if (![_repo commitWithMessage:self.message
							   amend:NO
						outputBlock:outputBlock
							   error:&error])
      if (error != nil)
                   [XTStatusView updateStatus:@"Commit failed"
                                      command:@"commit"
                                       output:[[error userInfo]
                                               valueForKey:XTErrorOutputKey]
                                forRepository:_repo];
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
  NSURL *url = [_repo.repoURL URLByAppendingPathComponent:file];
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
  [_repo executeOffMainThread:^{
	  _stagedFile = NO;
	  _actualDiff = [_repo diffForUnstagedFile:file.name];
	  if ([_actualDiff length] == 0)
		  _actualDiff = [self diffForNewFile:file.name];

	  [self showDiff:[XTHTML parseDiff:_actualDiff]];
  }];
}

- (void)showStageFile:(XTFileIndexInfo *)file
{
  [_repo executeOffMainThread:^{
	  _stagedFile = YES;
	  _actualDiff = [_repo diffForStagedFile:file.name];

	  NSString *diffHTML = [XTHTML parseDiff:_actualDiff];
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
    [[_web mainFrame] loadHTMLString:html baseURL:htmlURL];
  });
}

- (void)clearDiff
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [[_web mainFrame] loadHTMLString:@"" baseURL:nil];
  });
}

- (void)stagedDoubleClicked:(id)sender
{
  NSTableView *tableView = (NSTableView *)sender;
  const NSInteger clickedRow = [tableView clickedRow];

  if (clickedRow == -1)
    return;

  XTFileIndexInfo *item = [_stageDS items][clickedRow];

  [_repo executeOffMainThread:^{
	  if ([_repo unstageFile:item.name])
		  [self reload];
  }];
}

- (void)unstagedDoubleClicked:(id)sender
{
  NSTableView *tableView = (NSTableView *)sender;
  const NSInteger clickedRow = [tableView clickedRow];

  if (clickedRow == -1)
    return;

  XTFileIndexInfo *item = [_unstageDS items][clickedRow];

  [_repo executeOffMainThread:^{
	  if ([_repo stageFile:item.name])
		  [self reload];
  }];
}

#pragma mark -

- (void)unstageChunk:(NSInteger)idx
{
  [_repo executeOffMainThread:^{
	  [_repo unstagePatch:[self preparePatch:idx]];
	  [self reload];
  }];
}

- (void)stageChunk:(NSInteger)idx
{
  [_repo executeOffMainThread:^{
	  [_repo stagePatch:[self preparePatch:idx]];
	  [self reload];
  }];
}

- (void)discardChunk:(NSInteger)idx
{
  [_repo executeOffMainThread:^{
	  [_repo discardPatch:[self preparePatch:idx]];
	  [self reload];
  }];
}

#pragma mark -

- (NSString *)preparePatch:(NSInteger)idx
{
  NSArray *components = [_actualDiff componentsSeparatedByString:@"\n@@"];
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
  DOMDocument *dom = [[_web mainFrame] DOMDocument];
  DOMNodeList *headers =
      [dom getElementsByClassName:@"header"];  // TODO: change class names

  for (int n = 0; n < headers.length; n++) {
    DOMHTMLElement *header = (DOMHTMLElement *)[headers item:n];
    if (_stagedFile) {
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
    if ([table isEqualTo:_stageTable]) {
      [_unstageTable deselectAll:nil];
      XTFileIndexInfo *item = [_stageDS items][table.selectedRow];
      [self showStageFile:item];
    } else if ([table isEqualTo:_unstageTable]) {
      [_stageTable deselectAll:nil];
      XTFileIndexInfo *item = [_unstageDS items][table.selectedRow];
      [self showUnstageFile:item];
    }
  } else {
    [self clearDiff];
  }
}

@end
