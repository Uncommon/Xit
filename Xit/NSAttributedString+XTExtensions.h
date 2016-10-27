#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSAttributedString (XTExtensions)

+ (nullable NSAttributedString *)
    attributedStringWithFormat:(NSString*)format
                  placeholders:(NSArray<NSString*>*)placeholders
                  replacements:(NSArray<NSString*>*)replacements
                    attributes:(NSDictionary*)attributes
         replacementAttributes:(NSDictionary*)replacementAttributes;

@end

NS_ASSUME_NONNULL_END
