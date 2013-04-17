//
//  XTRefTokenTest.m
//  Xit
//
//  Created by David Catmull on 3/9/13.
//
//

#import <SenTestingKit/SenTestingKit.h>
#import "XTRefToken.h"
#import "XTRepository+Commands.h"
#import <OCMock/OCMock.h>

@interface XTRefTokenTest : SenTestCase

@end

@implementation XTRefTokenTest

- (void)testTypeForRefName {
    id repo = [OCMockObject mockForClass:[XTRepository class]];

    [[[repo expect] andReturn:@"feature"] currentBranch];
    STAssertEquals([XTRefToken typeForRefName:@"refs/heads/master" inRepository:repo], XTRefTypeBranch, @"");
    [[[repo expect] andReturn:@"feature"] currentBranch];
    STAssertEquals([XTRefToken typeForRefName:@"refs/heads/feature" inRepository:repo], XTRefTypeActiveBranch, @"");
    STAssertEquals([XTRefToken typeForRefName:@"refs/tags/1.0" inRepository:repo], XTRefTypeTag, @"");
    STAssertEquals([XTRefToken typeForRefName:@"stash{0}" inRepository:repo], XTRefTypeUnknown, @"");
}

@end
