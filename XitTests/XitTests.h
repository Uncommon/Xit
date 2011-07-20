//
//  XitTests.h
//  XitTests
//
//  Created by glaullon on 7/15/11.
//

#import <SenTestingKit/SenTestingKit.h>

@class Xit;

@interface XitTests : SenTestCase {
@private
    NSString *repo;
    NSString *remoteRepo;
    Xit *xit;
    BOOL reloadDetected;
}

- (Xit *)createRepo:(NSString *)repoName;
- (void)testXTSideBarDataSourceReomtes;
- (void)testGitError;

@end
