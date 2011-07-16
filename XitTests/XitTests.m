//
//  XitTests.m
//  XitTests
//
//  Created by glaullon on 7/15/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import "XitTests.h"

@implementation XitTests

- (void)setUp
{
    [super setUp];
    
    path=[NSString stringWithFormat:@"%@testrepo",NSTemporaryDirectory()];
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSURL *repoURL=[NSURL URLWithString:[NSString stringWithFormat:@"%@.git",path]];
    
    xit=[[Xit alloc] initWithContentsOfURL:repoURL ofType:@"git" error:nil];
    
    if(![xit initRepo]){
        STFail(@"initRepo FAIL!!");
    }
    
    if(![defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/.git",path]]){
        STFail(@".git NOT Found!!");
    }
    
    NSString *testFile=[NSString stringWithFormat:@"%@/file1.txt",path];
    NSString *txt=@"some text";
    [txt writeToFile:testFile atomically:YES encoding:NSASCIIStringEncoding error:nil];
    
    if(![defaultManager fileExistsAtPath:testFile]){
        STFail(@"testFile NOT Found!!");
    }
    
    NSLog(@"setUp ok");
}

- (void)tearDown
{
    [super tearDown];

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [defaultManager removeItemAtPath:path error:nil];
    
    if([defaultManager fileExistsAtPath:path]){
        STFail(@"tearDown FAIL!!");
    }
        
    NSLog(@"tearDown ok");
}

- (void)testRepo
{
    if(![xit addFile:@"file1.txt"]){
        STFail(@"add file 'file1.txt'");
    }
    
    if(![xit commitWithMessage:@"new file1.txt"]){
        STFail(@"Commit with mesage 'new file1.txt'");
    }
    
    if(![xit createBranch:@"b1"]){
        STFail(@"Create Branch 'b1'");
    }
}

@end
