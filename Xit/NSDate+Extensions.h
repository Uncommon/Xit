#import <Cocoa/Cocoa.h>
@interface NSDate (RFC2822)

+ (NSDate *)dateFromRFC2822:(NSString *)rfc2822;

@end
