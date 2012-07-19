//
//  XTStageViewController.m
//  Xit
//
//  Created by German Laullon on 10/08/11.
//

#import "XTStageViewController.h"
#import "XTFileIndexInfo.h"
#import "XTRepository.h"
#import "XTHTML.h"

@implementation XTStageViewController

- (void)awakeFromNib {
    [stageTable setTarget:self];
    [stageTable setDoubleAction:@selector(stagedDoubleClicked:)];
    [unstageTable setTarget:self];
    [unstageTable setDoubleAction:@selector(unstagedDoubleClicked:)];
}

- (NSString *)nibName {
    NSLog(@"nibName: %@ (%@)", [super nibName], [self class]);
    return NSStringFromClass([self class]);
}

- (void)setRepo:(XTRepository *)newRepo {
    repo = newRepo;
    [stageDS setRepo:repo];
    [unstageDS setRepo:repo];
}

- (void)reload {
    [stageDS reload];
    [unstageDS reload];
    [repo executeOffMainThread:^{
        // Do this in the repo queue so it will happen after the reloads.
        [stageTable reloadData];
        [unstageTable reloadData];
    }];
}

#pragma mark -

- (void)showUnstageFile:(XTFileIndexInfo *)file {
    dispatch_async(repo.queue, ^{
                       NSData *output = [repo executeGitWithArgs:[NSArray arrayWithObjects:@"diff-files", @"--patch", @"--", file.name, nil] error:nil];

                       actualDiff = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
                       stagedFile = NO;

                       NSString *diffHTML = [XTHTML parseDiff:actualDiff];
                       [self showDiff:diffHTML];
                   });
}

- (void)showStageFile:(XTFileIndexInfo *)file {
    dispatch_async(repo.queue, ^{
                       NSData *output = [repo executeGitWithArgs:[NSArray arrayWithObjects:@"diff-index",  @"--patch", @"--cached", [repo parentTree], @"--", file.name, nil] error:nil];

                       actualDiff = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
                       stagedFile = YES;

                       NSString *diffHTML = [XTHTML parseDiff:actualDiff];
                       [self showDiff:diffHTML];
                   });
}

- (void)showDiff:(NSString *)diff {
    NSString *html = [NSString stringWithFormat:@"<html><head><link rel='stylesheet' type='text/css' href='diff.css'/></head><body><div id='diffs'>%@</div></body></html>", diff];

    NSBundle *bundle = [NSBundle mainBundle];
    NSBundle *theme = [NSBundle bundleWithURL:[bundle URLForResource:@"html.theme.default" withExtension:@"bundle"]];
    NSURL *themeURL = [[theme bundleURL] URLByAppendingPathComponent:@"Contents/Resources"];

    dispatch_async(dispatch_get_main_queue(), ^{
                       [[web mainFrame] loadHTMLString:html baseURL:themeURL];
                   });
}

- (void)clearDiff {
    dispatch_async(
            dispatch_get_main_queue(),
            ^{ [[web mainFrame] loadHTMLString:@"" baseURL:nil]; });
}

- (void)stagedDoubleClicked:(id)sender {
    NSTableView *tableView = (NSTableView *)sender;
    const NSInteger clickedRow = [tableView clickedRow];

    if (clickedRow == -1)
        return;

    XTFileIndexInfo *item = [[stageDS items] objectAtIndex:clickedRow];

    [repo executeOffMainThread:^{
        NSArray *args;
        NSError *error = nil;

        if ([repo parseReference:@"HEAD"] == nil)
            args = [NSArray arrayWithObjects:@"rm", @"--cached", item.name, nil];
        else
            args = [NSArray arrayWithObjects:@"reset", @"HEAD", item.name, nil];
        [repo executeGitWithArgs:args error:&error];
        [self reload];
    }];
}

- (void)unstagedDoubleClicked:(id)sender {
    NSTableView *tableView = (NSTableView *)sender;
    const NSInteger clickedRow = [tableView clickedRow];

    if (clickedRow == -1)
        return;

    XTFileIndexInfo *item = [[unstageDS items] objectAtIndex:clickedRow];

    [repo executeOffMainThread:^{
        NSArray *args = [NSArray arrayWithObjects:@"add", item.name, nil];
        NSError *error = nil;

        [repo executeGitWithArgs:args error:&error];
        if (error == nil)
            [self reload];
    }];
}

#pragma mark -

- (void)unstageChunk:(NSInteger)idx {
    [repo executeOffMainThread:^{
        [repo executeGitWithArgs:[NSArray arrayWithObjects:@"apply",  @"--cached", @"--reverse", nil]
                       withStdIn:[self preparePatch:idx]
                           error:nil];
        [self reload];
    }];
}

- (void)stageChunk:(NSInteger)idx {
    [repo executeOffMainThread:^{
        [repo executeGitWithArgs:[NSArray arrayWithObjects:@"apply",  @"--cached", nil]
                       withStdIn:[self preparePatch:idx]
                           error:nil];
        [self reload];
    }];
}

- (void)discardChunk:(NSInteger)idx {
    // TODO: implement discard
}

#pragma mark -

- (NSString *)preparePatch:(NSInteger)idx {
    NSArray *comps = [actualDiff componentsSeparatedByString:@"\n@@"];
    NSMutableString *patch = [NSMutableString stringWithString:[comps objectAtIndex:0]]; // Header

    [patch appendString:@"\n@@"];
    [patch appendString:[comps objectAtIndex:(idx + 1)]];
    [patch appendString:@"\n"];
    return patch;
}


#pragma mark - WebFrameLoadDelegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    DOMDocument *dom = [[web mainFrame] DOMDocument];
    DOMNodeList *headers = [dom getElementsByClassName:@"header"]; // TODO: change class names

    for (int n = 0; n < headers.length; n++) {
        DOMHTMLElement *header = (DOMHTMLElement *)[headers item:n];
        if (stagedFile) {
            [[[header children] item:0] appendChild:[self createButtonWithIndex:n title:@"Unstage" fromDOM:dom]];
        } else {
            [[[header children] item:0] appendChild:[self createButtonWithIndex:n title:@"Stage" fromDOM:dom]];
            [[[header children] item:0] appendChild:[self createButtonWithIndex:n title:@"Discard" fromDOM:dom]];
        }
    }
}

- (DOMHTMLElement *)createButtonWithIndex:(int)index title:(NSString *)title fromDOM:(DOMDocument *)dom {
    DOMHTMLInputElement *bt = (DOMHTMLInputElement *)[dom createElement:@"input"];

    bt.type = @"button";
    bt.value = title;
    bt.name = [NSString stringWithFormat:@"%d", index];
    [bt addEventListener:@"click" listener:self useCapture:YES];
    return bt;
}

#pragma mark - DOMEventListener

- (void)handleEvent:(DOMEvent *)evt {
    DOMHTMLInputElement *bt = (DOMHTMLInputElement *)evt.target;

    NSLog(@"handleEvent: %@ - %@", bt.value, bt.name);
    if ([bt.value isEqualToString:@"Unstage"]) {
        [self unstageChunk:[bt.name intValue]];
    } else if ([bt.value isEqualToString:@"Stage"]) {
        [self stageChunk:[bt.name intValue]];
    } else if ([bt.value isEqualToString:@"Discard"]) {
        [self discardChunk:[bt.name intValue]];
    }
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    NSTableView *table = (NSTableView *)aNotification.object;

    if (table.numberOfSelectedRows > 0) {
        if ([table isEqualTo:stageTable]) {
            [unstageTable deselectAll:nil];
            XTFileIndexInfo *item = [[stageDS items] objectAtIndex:table.selectedRow];
            [self showStageFile:item];
        } else if ([table isEqualTo:unstageTable]) {
            [stageTable deselectAll:nil];
            XTFileIndexInfo *item = [[unstageDS items] objectAtIndex:table.selectedRow];
            [self showUnstageFile:item];
        }
    } else {
        [self clearDiff];
    }
}
@end
