//
//  XTFileListDataSource.m
//  Xit
//
//  Created by German Laullon on 13/09/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "XTFileListDataSourceTest.h"
#import "XTHistoryDataSource.h"
#import "GITBasic+XTRepository.h"
#import "XTFileListDataSource.h"
#import "XTHistoryItem.h"

@implementation XTFileListDataSourceTest

- (void)testFileList {
    NSString *txt = @"some text";

    for (int n = 0; n < 10; n++) {
        NSString *file = [NSString stringWithFormat:@"%@/file_%lu.txt", repo, n];
        [txt writeToFile:file atomically:YES encoding:NSASCIIStringEncoding error:nil];
        [xit addFile:@"--all"];
        [xit commitWithMessage:@"commit"];
    }

    XTHistoryDataSource *hds = [[XTHistoryDataSource alloc] init];
    [hds setRepo:xit];
    [xit waitUntilReloadEnd];

    XTHistoryItem *item = (XTHistoryItem *)[hds.items objectAtIndex:0];
    xit.selectedCommit = item.sha;

    XTFileListDataSource *flds = [[XTFileListDataSource alloc] init];
    [flds setRepo:xit];
    [xit waitUntilReloadEnd];

    NSInteger nf = [flds outlineView:nil numberOfChildrenOfItem:nil];
    STAssertTrue((nf == 11), @"found %d files", nf);

}

@end
