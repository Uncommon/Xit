#import <Foundation/Foundation.h>

@interface NSAttributedString (XTExtensions)

+ (NSAttributedString *)attributedStringWithFormat:(NSString *)format placeholders:(NSArray *)placeholders replacements:(NSArray *)replacements attributes:(NSDictionary *)attributes replacementAttributes:(NSDictionary *)replacementAttributes;

@end
