#import <Foundation/Foundation.h>

@interface NSTask (Throwing)

/// Wraps `-[NSTask launch]`, catching any runtime exceptions and returning
/// them as errors.
-(BOOL) throwingLaunchWithError:(NSError**)error;

@end
