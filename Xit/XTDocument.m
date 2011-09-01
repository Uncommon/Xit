//
//  Xit.m
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import "XTDocument.h"
#import "XTHistoryView.h"
#import "XTRepository.h"

@implementation XTDocument

- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    self = [super initWithContentsOfURL:absoluteURL ofType:typeName error:outError];
    if (self) {
        absoluteURL = [absoluteURL URLByDeletingPathExtension];
        repoURL = absoluteURL;
        repo = [[XTRepository alloc] initWithURL:repoURL];
    }
    return self;
}

- (NSString *)windowNibName {
    return @"Xit";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];

    [historyView loadView];
    NSTabViewItem *tabViewHistory = [tabs tabViewItemAtIndex:0];
    [[historyView view] setFrame:NSMakeRect(0, 0, [[historyView view] frame].size.width, [[historyView view] frame].size.height)];
    [tabViewHistory setView:[historyView view]];
    [historyView setRepo:repo];

    [stageView loadView];
    NSTabViewItem *tabViewStage = [tabs tabViewItemAtIndex:1];
    [[stageView view] setFrame:NSMakeRect(0, 0, [[stageView view] frame].size.width, [[stageView view] frame].size.height)];
    [tabViewStage setView:[stageView view]];
    [stageView setRepo:repo];

    [repo start];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    return true; // XXX
}


#pragma mark - temp
- (IBAction)reload:(id)sender {
    NSLog(@"########## reload ##########");
    [self setValue:[NSArray arrayWithObjects:@".git/refs/", @".git/logs/", nil] forKey:@"reload"];
}
@end
