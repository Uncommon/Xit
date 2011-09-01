//
//  XitTests.h
//  XitTests
//
//  Created by glaullon on 7/15/11.
//

#import <SenTestingKit/SenTestingKit.h>

@class XTRepository;

@interface XitTests : SenTestCase {
    NSString *repo;
    NSString *remoteRepo;
    XTRepository *xit;
    BOOL reloadDetected;
}

- (XTRepository *) createRepo:(NSString *)repoName;
@end
