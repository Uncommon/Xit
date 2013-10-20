#import <Foundation/Foundation.h>

#import <Cocoa/Cocoa.h>
@interface NSAttributedString (XTExtensions)

+ (NSAttributedString *)
    attributedStringWithFormat:(NSString *)format
                  placeholders:(NSArray *)placeholders
                  replacements:(NSArray *)replacements
                    attributes:(NSDictionary *)attributes
         replacementAttributes:(NSDictionary *)replacementAttributes;

@end
