#import "XTRefFormatter.h"
#include <git2.h>

@implementation XTRefFormatter

- (NSString *)stringForObjectValue:(id)value
{
  if ([value isKindOfClass:[NSString class]])
    return value;
  if ([value respondsToSelector:@selector(string)])
    return [value string];
  if ([value respondsToSelector:@selector(stringValue)])
    return [value stringValue];
  return nil;
}

- (BOOL)getObjectValue:(id *)object
             forString:(NSString *)string
      errorDescription:(NSString **)error
{
  *object = string;
  return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr
       proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
              originalString:(NSString *)origString
       originalSelectedRange:(NSRange)origSelRange
            errorDescription:(NSString **)error
{
  return [[self class] isValidRefString:*partialStringPtr];
}

+ (BOOL)isValidRefString:(NSString*)ref
{
  const char *cString = [ref cStringUsingEncoding:NSUTF8StringEncoding];

  if (cString == NULL)
    return NO;
  return git_reference_is_valid_name(cString);
}

@end
