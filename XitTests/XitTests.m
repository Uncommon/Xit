//
//  XitTests.m
//  XitTests
//
//  Created by glaullon on 7/15/11.
//

#import "XitTests.h"
#import "XTRepository.h"
#import "GITBasic+XTRepository.h"

@implementation XitTests

- (void) setUp {
    [super setUp];

    repo = [NSString stringWithFormat:@"%@testrepo", NSTemporaryDirectory()];
    xit = [self createRepo:repo];

    remoteRepo = [NSString stringWithFormat:@"%@remotetestrepo", NSTemporaryDirectory()];
    [self createRepo:remoteRepo];

    NSLog(@"setUp ok");
}

- (void) tearDown {
    [super tearDown];

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [defaultManager removeItemAtPath:repo error:nil];
    [defaultManager removeItemAtPath:remoteRepo error:nil];

    if ([defaultManager fileExistsAtPath:repo]) {
        STFail(@"tearDown %@ FAIL!!", repo);
    }

    if ([defaultManager fileExistsAtPath:remoteRepo]) {
        STFail(@"tearDown %@ FAIL!!", remoteRepo);
    }

    NSLog(@"tearDown ok");
}

// - (void)testGitError
// {
//    NSError *error = nil;
//    [xit exectuteGitWithArgs:[NSArray arrayWithObjects:@"checkout",@"-b",@"b1",nil] error:&error];
//    [xit exectuteGitWithArgs:[NSArray arrayWithObjects:@"checkout",@"-b",@"b1",nil] error:&error];
//    STAssertTrue(error!=nil, @"no error");
//    STAssertTrue([error code]!=0, @"no error");
// }

- (XTRepository *) createRepo:(NSString *)repoName {
    NSLog(@"[createRepo] repoName=%@", repoName);
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    if ([defaultManager fileExistsAtPath:repoName]) {
        [defaultManager removeItemAtPath:repoName error:nil];
    }
    [defaultManager createDirectoryAtPath:repoName withIntermediateDirectories:YES attributes:nil error:nil];

    NSURL *repoURL = [NSURL URLWithString:repoName];

    XTRepository *res = [[XTRepository alloc] initWithURL:repoURL];

    NSString *testFile = [NSString stringWithFormat:@"%@/file1.txt", repoName];
    NSString *txt = @"some text";
    [txt writeToFile:testFile atomically:YES encoding:NSASCIIStringEncoding error:nil];

    if (![defaultManager fileExistsAtPath:testFile]) {
        STFail(@"testFile NOT Found!!");
    }

    if (![res initRepo]) {
        STFail(@"initRepo '%@' FAIL!!", repoName);
    }

    if (![defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/.git", repoName]]) {
        STFail(@"%@/.git NOT Found!!", repoName);
    }

    if (![res addFile:@"file1.txt"]) {
        STFail(@"add file 'file1.txt'");
    }

    if (![res commitWithMessage:@"new file1.txt"]) {
        STFail(@"Commit with mesage 'new file1.txt'");
    }

    return res;
}
@end
