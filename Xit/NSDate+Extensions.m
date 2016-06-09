static NSDateFormatter *rfc2822Instance = nil;

@implementation NSDate (RFC2822)

+ (NSDateFormatter *)rfc2822Formatter
{
  @synchronized(self) {
    if (rfc2822Instance == nil) {
      rfc2822Instance = [[NSDateFormatter alloc] init];
      NSLocale *enUS = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
      rfc2822Instance.locale = enUS;
      rfc2822Instance.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss ZZ";
    }
  }
  return rfc2822Instance;
}

+ (NSDate *)dateFromRFC2822:(NSString *)rfc2822
{
  NSDateFormatter *formatter = [NSDate rfc2822Formatter];

  if ([NSThread isMainThread]) {
    return [formatter dateFromString:rfc2822];
  } else {
    __block NSDate *result = nil;

    dispatch_sync(dispatch_get_main_queue(), ^{
      result = [formatter dateFromString:rfc2822];
    });
    return result;
  }
}

@end
