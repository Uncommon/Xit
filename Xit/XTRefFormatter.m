#import "XTRefFormatter.h"

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
  if ([ref length] == 0)
    return NO;
  
  // The rules, according to git help check-ref-format:

  // They can include slash / for hierarchical (directory) grouping, but no
  // slash-separated component can begin with a dot . or end with the
  // sequence .lock.
  if (([ref rangeOfString:@"/."].location != NSNotFound) ||
      ([ref rangeOfString:@".lock/"].location != NSNotFound) ||
      [ref hasPrefix:@".lock"])
    return NO;

  // They must contain at least one /. This enforces the presence of a
  // category like heads/, tags/ etc. but the actual names are not
  // restricted. If the --allow-onelevel option is used, this rule is
  // waived.
  // (We're effectively doing allow-onelevel here)

  // They cannot have two consecutive dots .. anywhere.
  if ([ref rangeOfString:@".."].location != NSNotFound)
    return NO;

  // They cannot have ASCII control characters (i.e. bytes whose values are
  // lower than \040, or \177 DEL), space, tilde ~, caret ^, or colon :
  // anywhere.
  NSMutableCharacterSet *controlEtc =
      [[NSCharacterSet controlCharacterSet] mutableCopy];

  [controlEtc formUnionWithCharacterSet:
      [NSCharacterSet characterSetWithCharactersInString:@" ~^:"]];
  if ([ref rangeOfCharacterFromSet:controlEtc].location !=
      NSNotFound)
    return NO;

  // They cannot have question-mark ?, asterisk *, or open bracket [
  // anywhere.
  NSCharacterSet *qab =
      [NSCharacterSet characterSetWithCharactersInString:@"?*["];

  if ([ref rangeOfCharacterFromSet:qab].location != NSNotFound)
    return NO;

  // They cannot begin or end with a slash / or contain multiple consecutive
  // slashes
  if ([ref hasPrefix:@"/"] ||
      [ref hasSuffix:@"/"] ||
      ([ref rangeOfString:@"//"].location != NSNotFound))
    return NO;

  // They cannot end with a dot ".".
  if ([ref hasSuffix:@"."])
    return NO;

  // They cannot contain a sequence "@{".
  if ([ref rangeOfString:@"@{"].location != NSNotFound)
    return NO;
  //
  // They cannot contain a "\".
  if ([ref rangeOfString:@"\\"].location != NSNotFound)
    return NO;

  return YES;
}

@end
