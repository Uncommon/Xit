//
//  XitTests.h
//  XitTests
//
//  Created by glaullon on 7/15/11.
//

#import <SenTestingKit/SenTestingKit.h>

@class XTRepository;

@interface XitTests : SenTestCase {
    NSString *repoPath;
    NSString *remoteRepoPath;
    XTRepository *repository, *remoteRepository;
    BOOL reloadDetected;
}

- (XTRepository *)createRepo:(NSString *)repoName;
- (void)addInitialRepoContent;

@end
