//
//  XTStageViewControllerTest.m
//  Xit
//
//  Created by German Laullon on 09/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "XTStageViewControllerTest.h"
#import "XTUnstagedDataSource.h"
#import "XTStagedDataSource.h"
#import "GITBasic+XTRepository.h"
#import "XTFileIndexInfo.h"
#import "XTStageViewController.h"

@implementation XTStageViewControllerTest

- (void)testXTPartialStage {
    NSString *mv = [NSString stringWithFormat:@"%@/file_to_move.txt", repoPath];
    NSMutableArray *lines = [NSMutableArray arrayWithCapacity:30];

    for (int n = 0; n < 30; n++) {
        [lines addObject:[NSString stringWithFormat:@"line number %d", n]];
    }
    [[lines componentsJoinedByString:@"\n"] writeToFile:mv atomically:YES encoding:NSASCIIStringEncoding error:nil];

    [repository addFile:@"--all"];
    [repository commitWithMessage:@"commit"];

    [lines replaceObjectAtIndex:5 withObject:@"new line number 5......."];
    [lines replaceObjectAtIndex:15 withObject:@"new line number 15......."];
    [lines replaceObjectAtIndex:25 withObject:@"new line number 25......."];

    [[lines componentsJoinedByString:@"\n"] writeToFile:mv atomically:YES encoding:NSASCIIStringEncoding error:nil];

    XTUnstagedDataSource *ustgds = [[XTUnstagedDataSource alloc] init];
    [ustgds setRepo:repository];
    [repository waitUntilReloadEnd];

    NSUInteger nc = [ustgds numberOfRowsInTableView:nil];
    STAssertTrue((nc == 1), @"found %d commits", nc);

    XTStagedDataSource *stgds = [[XTStagedDataSource alloc] init];
    [stgds setRepo:repository];
    [repository waitUntilReloadEnd];

    nc = [stgds numberOfRowsInTableView:nil];
    STAssertTrue((nc == 0), @"found %d commits", nc);

    XTStageViewController *svc = [[XTStageViewController alloc] init];
    [svc setRepo:repository];
    [svc showUnstageFile:[ustgds.items objectAtIndex:0]]; // click on unstage table
    [svc stageChunk:2]; // click on stage button

    [ustgds reload];
    [repository waitUntilReloadEnd];

    nc = [ustgds numberOfRowsInTableView:nil];
    STAssertTrue((nc == 1), @"found %d commits", nc);

    [stgds reload];
    [repository waitUntilReloadEnd];

    nc = [stgds numberOfRowsInTableView:nil];
    STAssertTrue((nc == 1), @"found %d commits", nc);

    [svc showStageFile:[stgds.items objectAtIndex:0]]; // click on stage table
    [svc unstageChunk:0]; // click on unstage button

    [stgds reload];
    [repository waitUntilReloadEnd];

    nc = [stgds numberOfRowsInTableView:nil];
    STAssertTrue((nc == 0), @"found %d commits", nc);
}

- (void)testXTDataSources {
    NSString *mod = [NSString stringWithFormat:@"%@/file_to_mod.txt", repoPath];
    NSString *mv = [NSString stringWithFormat:@"%@/file_to_move.txt", repoPath];
    NSString *mvd = [NSString stringWithFormat:@"%@/file_moved.txt", repoPath];
    NSString *rm = [NSString stringWithFormat:@"%@/file_to_rm.txt", repoPath];
    NSString *new = [NSString stringWithFormat:@"%@/new_file.txt", repoPath];

    NSString *txt = @"some text";

    [txt writeToFile:mod atomically:YES encoding:NSASCIIStringEncoding error:nil];
    [txt writeToFile:mv atomically:YES encoding:NSASCIIStringEncoding error:nil];
    [txt writeToFile:rm atomically:YES encoding:NSASCIIStringEncoding error:nil];

    [repository addFile:@"--all"];
    [repository commitWithMessage:@"commit"];

    txt = @"more text";
    [txt writeToFile:mod atomically:YES encoding:NSASCIIStringEncoding error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:mv toPath:mvd error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:rm error:nil];
    [txt writeToFile:new atomically:YES encoding:NSASCIIStringEncoding error:nil];

    XTUnstagedDataSource *ustgds = [[XTUnstagedDataSource alloc] init];
    [ustgds setRepo:repository];
    [repository waitUntilReloadEnd];

    NSUInteger nc = [ustgds numberOfRowsInTableView:nil];
    STAssertTrue((nc == 5), @"found %d commits", nc);

    __block NSDictionary *expected = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"M", @"file_to_mod.txt",
                                      @"D", @"file_to_move.txt",
                                      @"?", @"file_moved.txt",
                                      @"D", @"file_to_rm.txt",
                                      @"?", @"new_file.txt",
                                      nil];

    NSArray *items = [ustgds items];
    [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
         XTFileIndexInfo *info = obj;
         NSString *status = [expected objectForKey:info.name];
         STAssertEqualObjects(info.status, status, @"incorrect state file(%lu):%@", idx, info.name);
     }];

    [repository addFile:@"--all"];

    XTStagedDataSource *stgds = [[XTStagedDataSource alloc] init];
    [stgds setRepo:repository];
    [repository waitUntilReloadEnd];

    nc = [stgds numberOfRowsInTableView:nil];
    STAssertTrue((nc == 5), @"found %d commits", nc);

    expected = [NSDictionary dictionaryWithObjectsAndKeys:
                @"M", @"file_to_mod.txt",
                @"D", @"file_to_move.txt",
                @"A", @"file_moved.txt",
                @"D", @"file_to_rm.txt",
                @"A", @"new_file.txt",
                nil];

    items = [stgds items];
    [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
         XTFileIndexInfo *info = obj;
         NSString *status = [expected objectForKey:info.name];
         STAssertEqualObjects(info.status, status, @"incorrect state file(%lu):%@", idx, info.name);
     }];
}

@end
