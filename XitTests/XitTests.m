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
#import "XTHistoryDataSource.h"
#import "XTSideBarDataSource.h"

@implementation XitTests

- (void)setUp
{
    [super setUp];
    
    repo=[NSString stringWithFormat:@"%@testrepo",NSTemporaryDirectory()];
    xit=[self createRepo:repo];
    
    remoteRepo=[NSString stringWithFormat:@"%@remotetestrepo",NSTemporaryDirectory()];
    [self createRepo:remoteRepo];
    
    NSLog(@"setUp ok");
}

- (void)tearDown
{
    [super tearDown];
    
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [defaultManager removeItemAtPath:repo error:nil];
    [defaultManager removeItemAtPath:remoteRepo error:nil];
    
    if([defaultManager fileExistsAtPath:repo]){
        STFail(@"tearDown %@ FAIL!!",repo);
    }
    
    if([defaultManager fileExistsAtPath:remoteRepo]){
        STFail(@"tearDown %@ FAIL!!",remoteRepo);
    }
    
    NSLog(@"tearDown ok");
}

- (void)testGitError
{
    NSError *error = nil;    
    [xit exectuteGitWithArgs:[NSArray arrayWithObjects:@"checkout",@"-b",@"b1",nil] error:&error];
    [xit exectuteGitWithArgs:[NSArray arrayWithObjects:@"checkout",@"-b",@"b1",nil] error:&error];
    STAssertTrue(error!=nil, @"no error");
    STAssertTrue([error code]!=0, @"no error");
}

- (void)testXTSideBarDataSourceReload
{
    XTSideBarDataSource *sbds=[[XTSideBarDataSource alloc] init];
    [sbds setRepo:xit];
    [sbds addObserver:self forKeyPath:@"reload" options:0 context:nil];
    
    [xit start];

    reloadDetected=NO;
    if(![xit createBranch:@"b1"]){
        STFail(@"Create Branch 'b1'");
    }
    
    int timeOut=0;
    while (!reloadDetected && (++timeOut<=10))
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        NSLog(@"Polling... (%d)",timeOut);
    }
    if(timeOut>10){
        STFail(@"TimeOut on reload");
    }
    
    id branchs=[sbds outlineView:nil child:XT_BRANCHS ofItem:nil];
    NSInteger nb=[sbds outlineView:nil numberOfChildrenOfItem:branchs];
    STAssertTrue((nb==2), @"found %d branchs FAIL",nb);
    
    [xit stop];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:@"reload"]){
        reloadDetected=YES;
    }
}

- (void)testXTSideBarDataSourceStashes
{
    NSString *testFile=[NSString stringWithFormat:@"%@/file1.txt",[[xit fileURL] absoluteString]];
    NSString *txt=@"other some text";
    [txt writeToFile:testFile atomically:YES encoding:NSASCIIStringEncoding error:nil];

    if(![xit stash:@"s1"]){
        STFail(@"stash");
    }
    
    XTSideBarDataSource *sbds=[[XTSideBarDataSource alloc] init];
    [sbds setRepo:xit];
    [sbds reload];
    
    id stashes=[sbds outlineView:nil child:XT_STASHES ofItem:nil];
    STAssertTrue((stashes!=nil), @"no stashes");
    
    NSInteger nr=[sbds outlineView:nil numberOfChildrenOfItem:stashes];
    STAssertTrue((nr==1), @"found %d stashes FAIL - stashes=%@",nr,stashes);
}

- (void)testXTSideBarDataSourceReomtes
{
    if(![xit checkout:@"master"]){
        STFail(@"checkout master");
    }
    
    if(![xit createBranch:@"b1"]){
        STFail(@"Create Branch 'b1'");
    }
    
    if(![xit AddRemote:@"origin" withUrl:remoteRepo]){
        STFail(@"add origin '%@'",remoteRepo);
    }
    
    if(![xit push:@"origin"]){
        STFail(@"push origin");
        return;
    }
    
    XTSideBarDataSource *sbds=[[XTSideBarDataSource alloc] init];
    [sbds setRepo:xit];
    [sbds reload];
    
    id remotes=[sbds outlineView:nil child:XT_REMOTES ofItem:nil];
    STAssertTrue((remotes!=nil), @"no remotes");
    
    NSInteger nr=[sbds outlineView:nil numberOfChildrenOfItem:remotes];
    STAssertTrue((nr==1), @"found %d remotes FAIL",nr);
    
    // BRANCHS
    id remote=[sbds outlineView:nil child:0 ofItem:remotes];
    NSString *rName=[sbds outlineView:nil objectValueForTableColumn:nil byItem:remote];
    STAssertTrue([rName isEqualToString:@"origin"], @"found remote '%@'",rName);

    NSInteger nb=[sbds outlineView:nil numberOfChildrenOfItem:remote];
    STAssertTrue((nb==2), @"found %d branchs FAIL",nb);
    
    bool branchB1Found=false;
    bool branchMasterFound=false;
    for (int n=0; n<nb; n++) {
        id branch=[sbds outlineView:nil child:n ofItem:remote];
        BOOL isExpandable=[sbds outlineView:nil isItemExpandable:branch];
        STAssertTrue(isExpandable==NO, @"Branchs must be no Expandable");
        
        NSString *bName=[sbds outlineView:nil objectValueForTableColumn:nil byItem:branch];
        if ([bName isEqualToString:@"master"]) {
            branchMasterFound=YES;
        }else if ([bName isEqualToString:@"b1"]) {
            branchB1Found=YES;
        }
    }
    STAssertTrue(branchMasterFound, @"Branch 'master' Not found");
    STAssertTrue(branchB1Found, @"Branch 'b1' Not found");
}

- (void)testXTSideBarDataSourceBranchsAndTags
{
    if(![xit createBranch:@"b1"]){
        STFail(@"Create Branch 'b1'");
    }
    
    if(![xit createTag:@"t1" withMessage:@"msg"]){
        STFail(@"Create Tag 't1'");
    }
    
    XTSideBarDataSource *sbds=[[XTSideBarDataSource alloc] init];
    [sbds setRepo:xit];
    [sbds reload];
    
    NSInteger nr=[sbds outlineView:nil numberOfChildrenOfItem:nil];
    STAssertTrue((nr==4), @"found %d roots FAIL",nr);
    
    // TAGS
    id tags=[sbds outlineView:nil child:XT_TAGS ofItem:nil];
    STAssertTrue((tags!=nil), @"no tags");
    
    NSInteger nt=[sbds outlineView:nil numberOfChildrenOfItem:tags];
    STAssertTrue((nt==1), @"found %d tags FAIL",nt);
    
    bool tagT1Found=false;
    for (int n=0; n<nt; n++) {
        id tag=[sbds outlineView:nil child:n ofItem:tags];
        BOOL isExpandable=[sbds outlineView:nil isItemExpandable:tag];
        STAssertTrue(isExpandable==NO, @"Tags must be no Expandable");
        
        NSString *bName=[sbds outlineView:nil objectValueForTableColumn:nil byItem:tag];
        if ([bName isEqualToString:@"t1"]) {
            tagT1Found=YES;
        }
    }
    STAssertTrue(tagT1Found, @"Tag 't1' Not found");
    
    // BRANCHS
    id branchs=[sbds outlineView:nil child:XT_BRANCHS ofItem:nil];
    STAssertTrue((branchs!=nil), @"no branchs FAIL");
    
    NSInteger nb=[sbds outlineView:nil numberOfChildrenOfItem:branchs];
    STAssertTrue((nb==2), @"found %d branchs FAIL",nb);
    
    bool branchB1Found=false;
    bool branchMasterFound=false;
    for (int n=0; n<nb; n++) {
        id branch=[sbds outlineView:nil child:n ofItem:branchs];
        BOOL isExpandable=[sbds outlineView:nil isItemExpandable:branch];
        STAssertTrue(isExpandable==NO, @"Branchs must be no Expandable");
        
        NSString *bName=[sbds outlineView:nil objectValueForTableColumn:nil byItem:branch];
        if ([bName isEqualToString:@"master"]) {
            branchMasterFound=YES;
        }else if ([bName isEqualToString:@"b1"]) {
            branchB1Found=YES;
        }
    }
    STAssertTrue(branchMasterFound, @"Branch 'master' Not found");
    STAssertTrue(branchB1Found, @"Branch 'b1' Not found");
}

- (void)testXTHistoryDataSource
{
    NSInteger nCommits=100;
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    for(int n=0;n<nCommits;n++){
        NSString *testFile=[NSString stringWithFormat:@"%@/file%d.txt",repo,n];
        NSString *txt=[NSString stringWithFormat:@"some text %d",n];
        [txt writeToFile:testFile atomically:YES encoding:NSASCIIStringEncoding error:nil];
        if(![defaultManager fileExistsAtPath:testFile]){
            STFail(@"testFile NOT Found!!");
        }
        if(![xit addFile:testFile]){
            STFail(@"add file '%@'",testFile);
        }
        if(![xit commitWithMessage:[NSString stringWithFormat:@"new %@",testFile]]){
            STFail(@"Commit with mesage 'new %@'",testFile);
        }
    }
    
    XTHistoryDataSource *hds=[[XTHistoryDataSource alloc] init];
    [hds setRepo:xit];
    [hds waitUntilReloadEnd];
    
    NSUInteger nc=[hds numberOfRowsInTableView:nil];
    STAssertTrue((nc==(nCommits+1)), @"found %d commits",nc);
}

- (Xit *)createRepo:(NSString *)repoName
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [defaultManager createDirectoryAtPath:repoName withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSURL *repoURL=[NSURL URLWithString:[NSString stringWithFormat:@"%@.git",repoName]];
    
    Xit *res=[[Xit alloc] initWithContentsOfURL:repoURL ofType:@"git" error:nil];
    
    NSString *testFile=[NSString stringWithFormat:@"%@/file1.txt",repoName];
    NSString *txt=@"some text";
    [txt writeToFile:testFile atomically:YES encoding:NSASCIIStringEncoding error:nil];
    
    if(![defaultManager fileExistsAtPath:testFile]){
        STFail(@"testFile NOT Found!!");
    }
    
    if(![res initRepo]){
        STFail(@"initRepo '%@' FAIL!!",repoName);
    }
    
    if(![defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/.git",repoName]]){
        STFail(@"%@/.git NOT Found!!",repoName);
    }
    
    if(![res addFile:@"file1.txt"]){
        STFail(@"add file 'file1.txt'");
    }
    
    if(![res commitWithMessage:@"new file1.txt"]){
        STFail(@"Commit with mesage 'new file1.txt'");
    }

    return res;
}
@end
