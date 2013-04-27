#import "XTCategoryTests.h"

#import <Cocoa/Cocoa.h>
#import "NSAttributedString+XTExtensions.h"

@implementation XTCategoryTests

- (void)testAttributedStringWithFormat {
    NSFont *systemFont = [NSFont systemFontOfSize:0];
    NSNumber *obliqueness = [NSNumber numberWithFloat:0.1];
    NSDictionary *baseAttributes = [NSDictionary dictionaryWithObject:systemFont forKey:NSFontAttributeName];
    NSDictionary *obliqueAttributes = [NSDictionary dictionaryWithObject:obliqueness forKey:NSObliquenessAttributeName];
    NSAttributedString *string = [NSAttributedString attributedStringWithFormat:@"Merge @~1 into @~2" placeholders:[NSArray arrayWithObjects:@"@~1", @"@~2", nil] replacements:[NSArray arrayWithObjects:@"branch", @"master", nil] attributes:baseAttributes replacementAttributes:obliqueAttributes];
    const NSRange fullRange = NSMakeRange(0, [[string string] length]);

    STAssertEqualObjects([string string], @"Merge branch into master", nil);

    NSRange effectiveRange;
    NSDictionary *attributes = [string attributesAtIndex:0 longestEffectiveRange:&effectiveRange inRange:fullRange];
    NSUInteger start = 0;

    STAssertEquals(effectiveRange.location, start, nil);
    STAssertEquals(effectiveRange.length, [@"Merge " length], nil);
    STAssertEquals([attributes count], (NSUInteger)1, nil);
    STAssertEqualObjects(systemFont, [attributes objectForKey:NSFontAttributeName], nil);
    start = effectiveRange.length;

    attributes = [string attributesAtIndex:start longestEffectiveRange:&effectiveRange inRange:fullRange];
    STAssertEquals(effectiveRange.location, [@"Merge " length], nil);
    STAssertEquals(effectiveRange.length, [@"branch" length], nil);
    STAssertEquals([attributes count], (NSUInteger)2, nil);
    STAssertEqualObjects(obliqueness, [attributes objectForKey:NSObliquenessAttributeName], nil);
    start = effectiveRange.location + effectiveRange.length;

    attributes = [string attributesAtIndex:start longestEffectiveRange:&effectiveRange inRange:fullRange];
    STAssertEquals(effectiveRange.location, [@"Merge branch" length], nil);
    STAssertEquals(effectiveRange.length, [@" into " length], nil);
    STAssertEquals([attributes count], (NSUInteger)1, nil);
    start = effectiveRange.location + effectiveRange.length;

    attributes = [string attributesAtIndex:start longestEffectiveRange:&effectiveRange inRange:fullRange];
    STAssertEquals(effectiveRange.location, [@"Merge branch into " length], nil);
    STAssertEquals(effectiveRange.length, [@"master" length], nil);
    STAssertEquals([attributes count], (NSUInteger)2, nil);
    STAssertEqualObjects(obliqueness, [attributes objectForKey:NSObliquenessAttributeName], nil);
}

@end
