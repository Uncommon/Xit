//
//  XTTest.h
//  XTTest
//
//  Created by glaullon on 7/15/11.
//

#import <SenTestingKit/SenTestingKit.h>

@class XTRepository;

@interface XTTest : SenTestCase {
    NSString *repoPath;
    NSString *remoteRepoPath;
    NSString *file1Path;
    XTRepository *repository, *remoteRepository;
    BOOL reloadDetected;
}

- (XTRepository *)createRepo:(NSString *)repoName;
- (void)addInitialRepoContent;
- (BOOL)writeTextToFile1:(NSString *)text;

@end
