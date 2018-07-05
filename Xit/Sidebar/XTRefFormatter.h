#import <Foundation/Foundation.h>

/**
  Formatter used to prevent the user from entering invalid ref names.
 */
@interface XTRefFormatter : NSFormatter

+ (BOOL)isValidRefString:(NSString*)ref;

@end
