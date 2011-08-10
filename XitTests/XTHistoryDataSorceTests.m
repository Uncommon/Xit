//
//  XTHistoryDataSorceTests.m
//  Xit
//
//  Created by German Laullon on 04/08/11.
//

#import "XTHistoryDataSorceTests.h"
#import "Xit.h"
#import "GITBasic+Xit.h"
#import "XTHistoryDataSource.h"
#import "XTHistoryItem.h"

@implementation XTHistoryDataSorceTests

- (void) testRootCommitsGraph {
    NSInteger nCommits = 15;
    NSFileManager * defaultManager = [NSFileManager defaultManager];

    for (int n = 0; n < nCommits; n++) {
        NSString * rn = [NSString stringWithFormat:@"refs/heads/root_%d", n];
        if ((n % 5) == 0) {
            NSData * data = [xit exectuteGitWithArgs:[NSArray arrayWithObjects:@"symbolic-ref", @"HEAD", rn, nil] error:nil];
            if (data == nil) {
                STFail(@"'%@' error", rn);
            }
            data = [xit exectuteGitWithArgs:[NSArray arrayWithObjects:@"rm", @"--cached", @"-r", @".", nil] error:nil];
            if (data == nil) {
                STFail(@"'%@' error", rn);
            }
            data = [xit exectuteGitWithArgs:[NSArray arrayWithObjects:@"clean", @"-f", @"-d", nil] error:nil];
            if (data == nil) {
                STFail(@"'%@' error", rn);
            }
        }

        NSString * testFile = [NSString stringWithFormat:@"%@/file%d.txt", repo, n];
        NSString * txt = [NSString stringWithFormat:@"some text %d", n];
        [txt writeToFile:testFile atomically:YES encoding:NSASCIIStringEncoding error:nil];

        if (![defaultManager fileExistsAtPath:testFile]) {
            STFail(@"testFile NOT Found!!");
        }
        if (![xit addFile:[testFile lastPathComponent]]) {
            STFail(@"add file '%@'", testFile);
        }
        if (![xit commitWithMessage:[NSString stringWithFormat:@"new %@", testFile]]) {
            STFail(@"Commit with mesage 'new %@'", testFile);
        }
    }

    XTHistoryDataSource * hds = [[XTHistoryDataSource alloc] init];
    [hds setRepo:xit];
    [hds waitUntilReloadEnd];

    NSArray * items = hds.items;
    [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
         XTHistoryItem * item = (XTHistoryItem *)obj;
         if (idx != (items.count - 1)) {
             STAssertTrue (item.lineInfo.numColumns == 1, @"%lu - incorrect numColumns=%lu", idx, item.lineInfo.numColumns);
         } else {
             STAssertTrue (item.lineInfo.numColumns == 0, @"%lu - incorrect numColumns=%lu", idx, item.lineInfo.numColumns);
         }
     }];
}

- (void) testXTHistoryDataSource {
    NSInteger nCommits = 60;
    NSFileManager * defaultManager = [NSFileManager defaultManager];

    for (int n = 0; n < nCommits; n++) {
        NSString * bn = [NSString stringWithFormat:@"branch_%d", n];
        if ((n % 10) == 0) {
            [xit checkout:@"master"];
            if (![xit createBranch:bn]) {
                STFail(@"Create Branch");
            }
        }

        NSString * testFile = [NSString stringWithFormat:@"%@/file%d.txt", repo, n];
        NSString * txt = [NSString stringWithFormat:@"some text %d", n];
        [txt writeToFile:testFile atomically:YES encoding:NSASCIIStringEncoding error:nil];

        if (![defaultManager fileExistsAtPath:testFile]) {
            STFail(@"testFile NOT Found!!");
        }
        if (![xit addFile:[testFile lastPathComponent]]) {
            STFail(@"add file '%@'", testFile);
        }
        if (![xit commitWithMessage:[NSString stringWithFormat:@"new %@", testFile]]) {
            STFail(@"Commit with mesage 'new %@'", testFile);
        }
    }

    XTHistoryDataSource * hds = [[XTHistoryDataSource alloc] init];
    [hds setRepo:xit];
    [hds waitUntilReloadEnd];

    NSUInteger nc = [hds numberOfRowsInTableView:nil];
    STAssertTrue((nc == (nCommits + 1)), @"found %d commits", nc);
}

@end
