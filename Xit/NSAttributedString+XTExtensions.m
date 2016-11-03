#import "NSAttributedString+XTExtensions.h"

@implementation NSAttributedString (XTExtensions)

+ (NSAttributedString *)
    attributedStringWithFormat:(NSString*)format
                  placeholders:(NSArray<NSString*>*)placeholders
                  replacements:(NSArray<NSString*>*)replacements
                    attributes:(NSDictionary*)attributes
         replacementAttributes:(NSDictionary*)replacementAttributes
{
  if (placeholders.count != replacements.count)
    return nil;

  NSMutableAttributedString *result =
      [[NSMutableAttributedString alloc] initWithString:format
                                             attributes:attributes];
  NSMutableString *resultString = [result mutableString];

  for (NSUInteger i = 0; i < placeholders.count; ++i) {
    const NSRange replaceRange = [resultString rangeOfString:placeholders[i]];

    [result addAttributes:replacementAttributes range:replaceRange];
    [resultString replaceCharactersInRange:replaceRange
                                withString:replacements[i]];
  }
  return result;
}

@end
