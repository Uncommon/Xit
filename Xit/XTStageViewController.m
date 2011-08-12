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
    DOMDocument *dom = [[web mainFrame] DOMDocument];
    DOMNodeList *headres = [dom getElementsByClassName:@"header"]; // TODO: change class names
    for (int n = 0; n < headres.length; n++) {
        DOMHTMLElement *header = (DOMHTMLElement *)[headres item:n];
        DOMHTMLAnchorElement *link = (DOMHTMLAnchorElement *)[dom createElement:@"a"];
        link.href = @"yyy";
        link.innerText = @"zzz";
        NSLog(@"header: '%@'", [header innerHTML]);
        NSLog(@"link:   '%@'", [link innerHTML]);
        [header appendChild:link];
        NSLog(@"header: '%@'", [header innerHTML]);
    }
}

- (void) showDiff:(NSString *)diff {
    NSString *html = [NSString stringWithFormat:@"<html><head><link rel='stylesheet' type='text/css' href='diff.css'/></head><body><div id='diffs'>%@</div></body></html>", diff];

    NSBundle *bundle = [NSBundle mainBundle];
    NSBundle *theme = [NSBundle bundleWithURL:[bundle URLForResource:@"html.theme.default" withExtension:@"bundle"]];
    NSURL *themeURL = [[theme bundleURL] URLByAppendingPathComponent:@"Contents/Resources"];

    [[web mainFrame] loadHTMLString:html baseURL:themeURL];
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
