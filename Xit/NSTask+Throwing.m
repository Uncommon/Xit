#import "NSTask+Throwing.h"

@implementation NSTask (Throwing)

- (BOOL) throwingLaunchWithError:(NSError *__autoreleasing *)error
{
  @try {
    [self launch];
  } @catch (NSException *exception) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                   code:NSFeatureUnsupportedError
                               userInfo:exception.userInfo];
    }
    return false;
  }
  return true;
}

@end
