//
//  XTRepositoryTests.m
//  Xit
//
//  Created by David Catmull on 7/6/12.
//

#import "XTRepositoryTests.h"

#import <Cocoa/Cocoa.h>
#import "XTRepository.h"

@implementation XTRepositoryTests

- (void)addInitialRepoContent {
}

- (void)testEmptyRepositoryHead {
    STAssertNil([repository parseReference:@"HEAD"], @"");
    STAssertEqualObjects([repository parentTree], kEmptyTreeHash, @"");
}

- (void)testHeadRef {
    [super addInitialRepoContent];
    // TODO: check that the values are correct
    STAssertNotNil([repository headRef], @"");
    STAssertNotNil([repository headSHA], @"");
}

@end
