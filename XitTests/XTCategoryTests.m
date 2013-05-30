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

  STAssertEqualObjects([string string], @"Merge branch into master", nil);

  NSRange effectiveRange;
  NSDictionary *attributes = [string attributesAtIndex:0
                                 longestEffectiveRange:&effectiveRange
                                               inRange:fullRange];
  NSUInteger start = 0;

  STAssertEquals(effectiveRange.location, start, nil);
  STAssertEquals(effectiveRange.length, [@"Merge " length], nil);
  STAssertEquals([attributes count], (NSUInteger) 1, nil);
  STAssertEqualObjects(systemFont, attributes[NSFontAttributeName], nil);
  start = effectiveRange.length;

  attributes = [string attributesAtIndex:start
                   longestEffectiveRange:&effectiveRange
                                 inRange:fullRange];
  STAssertEquals(effectiveRange.location, [@"Merge " length], nil);
  STAssertEquals(effectiveRange.length, [@"branch" length], nil);
  STAssertEquals([attributes count], (NSUInteger) 2, nil);
  STAssertEqualObjects(obliqueness, attributes[NSObliquenessAttributeName],
                       nil);
  start = effectiveRange.location + effectiveRange.length;

  attributes = [string attributesAtIndex:start
                   longestEffectiveRange:&effectiveRange
                                 inRange:fullRange];
  STAssertEquals(effectiveRange.location, [@"Merge branch" length], nil);
  STAssertEquals(effectiveRange.length, [@" into " length], nil);
  STAssertEquals([attributes count], (NSUInteger) 1, nil);
  start = effectiveRange.location + effectiveRange.length;

  attributes = [string attributesAtIndex:start
                   longestEffectiveRange:&effectiveRange
                                 inRange:fullRange];
  STAssertEquals(effectiveRange.location, [@"Merge branch into " length], nil);
  STAssertEquals(effectiveRange.length, [@"master" length], nil);
  STAssertEquals([attributes count], (NSUInteger) 2, nil);
  STAssertEqualObjects(obliqueness, attributes[NSObliquenessAttributeName],
                       nil);
}

@end
