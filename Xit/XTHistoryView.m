//
//  XTHistoryView.m
//  Xit
//
//  Created by German Laullon on 05/08/11.
//

#import "XTHistoryView.h"
#import "XTRepository.h"
#import "XTSideBarDataSource.h"
#import "XTCommitViewController.h"

@implementation XTHistoryView

+ (id)viewController {
    return [[[self alloc] initWithNibName:NSStringFromClass([self class]) bundle:nil] autorelease];
}

- (void)loadView {
    [super loadView];
    [self viewDidLoad];
}

- (void)viewDidLoad {
    NSLog(@"viewDidLoad");
}

- (void)setRepo:(XTRepository *)newRepo {
    repo = newRepo;
    [sideBarDS setRepo:newRepo];
    [historyDS setRepo:newRepo];
    [commitViewController setRepo:newRepo];
    [[commitViewController view] setFrame:NSMakeRect(0, 0, [commitView frame].size.width, [commitView frame].size.height)];
    [commitView addSubview:[commitViewController view]];
}

- (IBAction)toggleLayout:(id)sender {
    // TODO: improve it
    NSLog(@"toggleLayout, %lu,%d", ((NSButton *)sender).state, (((NSButton *)sender).state == 1));
    [mainSplitView setVertical:(((NSButton *)sender).state == 1)];
    [mainSplitView adjustSubviews];
}

- (IBAction)toggleSideBar:(id)sender {
    // TODO: improve it
    const CGFloat newWidth = ([sender state] == NSOnState) ? 180 : 0;
    [sidebarSplitView setPosition:newWidth ofDividerAtIndex:0 ];
}

@end
