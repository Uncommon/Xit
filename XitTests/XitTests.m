//
//  XitTests.m
//  XitTests
//
//  Created by glaullon on 7/15/11.
//

#import "XitTests.h"
#import "Xit.h"
#import "GITBasic+Xit.h"
#import "XTSideBarItem.h"
#import "XTSideBarDataSource.h"

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

- (void)testXTSideBarDataBranchSource
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
    
    XTSideBarDataSource *sbds=[[XTSideBarDataSource alloc] init];
    [sbds setRepo:xit];
    [sbds reload];
    
    id branchs=[sbds outlineView:nil child:XT_BRANCHS ofItem:nil];
    STAssertTrue((branchs!=nil), @"no branchs FAIL");

    NSInteger nb=[sbds outlineView:nil numberOfChildrenOfItem:branchs];
    STAssertTrue((nb==2), @"found %d branchs FAIL",nb);
    
    bool branchB1Found=false;
    for (int n=0; n<nb; n++) {
        id b=[sbds outlineView:nil child:n ofItem:branchs];
        NSString *bName=[sbds outlineView:nil objectValueForTableColumn:nil byItem:b];
        if ([bName isEqualToString:@"b1"]) {
            branchB1Found=YES;
        }
    }
    STAssertTrue(branchB1Found, @"Branch 'b1' Not found");

}

@end
