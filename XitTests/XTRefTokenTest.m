#import <XCTest/XCTest.h>
#import "XTRefToken.h"
#import "XTRepository+Commands.h"
#import <OCMock/OCMock.h>

@interface XTRefTokenTest : XCTestCase

@end

@implementation XTRefTokenTest

- (void)testTypeForRefName
{
  id repo = [OCMockObject mockForClass:[XTRepository class]];

  [[[repo expect] andReturn:@"feature"] currentBranch];
  XCTAssertEqual(
      [XTRefToken typeForRefName:@"refs/heads/master" inRepository:repo],
      XTRefTypeBranch, @"");
  [[[repo expect] andReturn:@"feature"] currentBranch];
  XCTAssertEqual(
      [XTRefToken typeForRefName:@"refs/heads/feature" inRepository:repo],
      XTRefTypeActiveBranch, @"");
  XCTAssertEqual([XTRefToken typeForRefName:@"refs/tags/1.0" inRepository:repo],
                 XTRefTypeTag, @"");
  XCTAssertEqual([XTRefToken typeForRefName:@"stash{0}" inRepository:repo],
                 XTRefTypeUnknown, @"");
}

@end
