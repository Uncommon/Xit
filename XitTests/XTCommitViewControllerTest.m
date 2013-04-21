//
//  XTCommitViewControllerTest.m
//  Xit
//
//  Created by German Laullon on 04/08/11.
//

#import "XTTest.h"
#import "XTRepository+Commands.h"
#import "XTSideBarItem.h"
#import "XTSideBarDataSource.h"
#import "XTCommitViewController.h"

@interface XTCommitViewControllerTest : XTTest

@end

@implementation XTCommitViewControllerTest

- (void)testCommitWithTag {
    NSString *tagName = @"TagNameTest";
    NSString *tagMsg = @"### message ###";

    if (![repository createTag:tagName withMessage:tagMsg]) {
        STFail(@"Create Tag 't1'");
    }

    XTSideBarDataSource *sbds = [[XTSideBarDataSource alloc] init];
    [sbds setRepo:repository];
    [self waitForRepoQueue];

    id tags = [sbds outlineView:nil child:XTTagsGroupIndex ofItem:nil];
    NSInteger count = [sbds outlineView:nil numberOfChildrenOfItem:tags];
    STAssertEquals(1L, count, @"");
    if (count != 1)
        return;  // abort test
    XTSideBarItem *tag = [sbds outlineView:nil child:0 ofItem:tags];

    XTCommitViewController *cvc = [[XTCommitViewController alloc] init];
    [cvc setRepo:repository];
    NSString *html = [cvc loadCommit:tag.sha];
    NSRange tagNameRange = [html rangeOfString:tagName];
    STAssertTrue(tagNameRange.location != NSNotFound, @"'%@' not found", tagName);
}

@end