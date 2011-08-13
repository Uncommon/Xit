//
//  XTStageViewController.m
//  Xit
//
//  Created by German Laullon on 10/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "XTStageViewController.h"
#import "XTFileIndexInfo.h"
#import "Xit.h"
#import "XTHTML.h"

@implementation XTStageViewController

+ (id) viewController {
    return [[[self alloc] initWithNibName:NSStringFromClass([self class]) bundle:nil] autorelease];
}

- (void) loadView {
    [super loadView];
    [self viewDidLoad];
}

- (void) viewDidLoad {
    NSLog(@"viewDidLoad");
}

- (void) setRepo:(Xit *)newRepo {
    repo = newRepo;
    [stageDS setRepo:repo];
    [unstageDS setRepo:repo];
}

#pragma mark -

- (void) showUnstageFile:(XTFileIndexInfo *)file {
    NSData *output = [repo exectuteGitWithArgs:[NSArray arrayWithObjects:@"diff-files", @"--patch", @"--", file.name, nil] error:nil];
    NSString *filesStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    NSString *diff = [XTHTML parseDiff:filesStr];

    [self showDiff:diff];
}

- (void) showStageFile:(XTFileIndexInfo *)file {
    NSData *output = [repo exectuteGitWithArgs:[NSArray arrayWithObjects:@"diff-index",  @"--patch", @"--cached", @"HEAD", @"--", file.name, nil] error:nil];
    NSString *filesStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    NSString *diff = [XTHTML parseDiff:filesStr];

    [self showDiff:diff];
}

- (void) showDiff:(NSString *)diff {
    NSString *html = [NSString stringWithFormat:@"<html><head><link rel='stylesheet' type='text/css' href='diff.css'/></head><body><div id='diffs'>%@</div></body></html>", diff];

    NSBundle *bundle = [NSBundle mainBundle];
    NSBundle *theme = [NSBundle bundleWithURL:[bundle URLForResource:@"html.theme.default" withExtension:@"bundle"]];
    NSURL *themeURL = [[theme bundleURL] URLByAppendingPathComponent:@"Contents/Resources"];

    [[web mainFrame] loadHTMLString:html baseURL:themeURL];
}

#pragma mark - WebFrameLoadDelegate

- (void) webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    DOMDocument *dom = [[web mainFrame] DOMDocument];
    DOMNodeList *headres = [dom getElementsByClassName:@"header"]; // TODO: change class names

    for (int n = 0; n < headres.length; n++) {
        DOMHTMLElement *header = (DOMHTMLElement *)[headres item:n];
        [[[header children] item:0] appendChild:[self createButtonWithIndex:n title:@"Stage" fromDOM:dom]];
        [[[header children] item:0] appendChild:[self createButtonWithIndex:n title:@"Discard" fromDOM:dom]];
    }
}

- (DOMHTMLElement *) createButtonWithIndex:(int)index title:(NSString *)title fromDOM:(DOMDocument *)dom {
    DOMHTMLInputElement *bt = (DOMHTMLInputElement *)[dom createElement:@"input"];

    bt.type = @"button";
    bt.value = title;
    bt.name = [NSString stringWithFormat:@"%d", index];
    [bt addEventListener:@"click" listener:self useCapture:YES];
    return bt;
}

#pragma mark - DOMEventListener

- (void) handleEvent:(DOMEvent *)evt {
    DOMHTMLInputElement *bt = (DOMHTMLInputElement *)evt.target;

    NSLog(@"handleEvent: %@ - %@", bt.value, bt.name);
}

#pragma mark - NSTableViewDelegate

- (void) tableViewSelectionDidChange:(NSNotification *)aNotification {
    NSLog(@"%@", aNotification);
    NSTableView *table = (NSTableView *)aNotification.object;
    if ([table isEqualTo:stageTable]) {
        XTFileIndexInfo *item = [[stageDS items] objectAtIndex:table.selectedRow];
        [self showStageFile:item];
    } else if ([table isEqualTo:unstageTable]) {
        XTFileIndexInfo *item = [[unstageDS items] objectAtIndex:table.selectedRow];
        [self showUnstageFile:item];
    }
}
@end
