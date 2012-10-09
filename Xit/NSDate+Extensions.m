//
//  NSDate+Extensions.m
//  Xit
//
//  Created by David Catmull on 8/6/11.
//


@implementation NSDate (RFC2822)

+ (NSDateFormatter *)rfc2822Formatter {
    static NSDateFormatter *formatter = nil;
    if (formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
        NSLocale *enUS = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        [formatter setLocale:enUS];
        [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZ"];
    }
    return formatter;
}

+ (NSDate *)dateFromRFC2822:(NSString *)rfc2822 {
    NSDateFormatter *formatter = [NSDate rfc2822Formatter];

    if ([NSThread isMainThread])
        return [formatter dateFromString:rfc2822];
    else {
        __block NSDate *result = nil;

        dispatch_sync(dispatch_get_main_queue(),
                      ^{ result = [formatter dateFromString:rfc2822]; });
        return result;
    }
}

@end
