#import "XTCategoryTests.h"

#import <Cocoa/Cocoa.h>
#import "NSAttributedString+XTExtensions.h"

@implementation XTCategoryTests

- (void)testAttributedStringWithFormat
{
  NSFont *systemFont = [NSFont systemFontOfSize:0];
  NSNumber *obliqueness = @0.1f;
  NSDictionary *baseAttributes = @{NSFontAttributeName : systemFont};
  NSDictionary *obliqueAttributes = @{NSObliquenessAttributeName : obliqueness};
  NSAttributedString *string =
      [NSAttributedString attributedStringWithFormat:@"Merge @~1 into @~2"
                                        placeholders:@[ @"@~1", @"@~2" ]
                                        replacements:@[ @"branch", @"master" ]
                                          attributes:baseAttributes
                               replacementAttributes:obliqueAttributes];
  const NSRange fullRange = NSMakeRange(0, [[string string] length]);

  XCTAssertEqualObjects([string string], @"Merge branch into master");

  NSRange effectiveRange;
  NSDictionary *attributes = [string attributesAtIndex:0
                                 longestEffectiveRange:&effectiveRange
                                               inRange:fullRange];
  NSUInteger start = 0;

  XCTAssertEqual(effectiveRange.location, start);
  XCTAssertEqual(effectiveRange.length, [@"Merge " length]);
  XCTAssertEqual([attributes count], (NSUInteger) 1);
  XCTAssertEqualObjects(systemFont, attributes[NSFontAttributeName]);
  start = effectiveRange.length;

  attributes = [string attributesAtIndex:start
                   longestEffectiveRange:&effectiveRange
                                 inRange:fullRange];
  XCTAssertEqual(effectiveRange.location, [@"Merge " length]);
  XCTAssertEqual(effectiveRange.length, [@"branch" length]);
  XCTAssertEqual([attributes count], (NSUInteger) 2);
  XCTAssertEqualObjects(obliqueness, attributes[NSObliquenessAttributeName]);
  start = effectiveRange.location + effectiveRange.length;

  attributes = [string attributesAtIndex:start
                   longestEffectiveRange:&effectiveRange
                                 inRange:fullRange];
  XCTAssertEqual(effectiveRange.location, [@"Merge branch" length]);
  XCTAssertEqual(effectiveRange.length, [@" into " length]);
  XCTAssertEqual([attributes count], (NSUInteger) 1);
  start = effectiveRange.location + effectiveRange.length;

  attributes = [string attributesAtIndex:start
                   longestEffectiveRange:&effectiveRange
                                 inRange:fullRange];
  XCTAssertEqual(effectiveRange.location, [@"Merge branch into " length]);
  XCTAssertEqual(effectiveRange.length, [@"master" length]);
  XCTAssertEqual([attributes count], (NSUInteger) 2);
  XCTAssertEqualObjects(obliqueness, attributes[NSObliquenessAttributeName]);
}

@end
