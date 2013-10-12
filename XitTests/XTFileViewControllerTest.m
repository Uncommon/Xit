#import "XTTest.h"
#import "XTFileViewController.h"

#import <Cocoa/Cocoa.h>
@interface XTFileViewControllerTest : SenTestCase

@end

@implementation XTFileViewControllerTest

- (void)testFileNameIsText
{
  NSDictionary *names = @{
      @"COPYING": @YES,
      @"a.txt": @YES,
      @"a.c": @YES,
      @"a.xml": @YES,
      @"a.html": @YES,
      @"a.jpg": @NO,
      @"a.png": @NO,
      @"a.ffff": @NO,
      @"AAAAA": @NO,
      };
  NSArray *keys = [names allKeys];
  NSArray *values = [names allValues];

  for (int i = 0; i < [keys count]; ++i)
    STAssertEqualObjects(
        @([XTFileViewController fileNameIsText:keys[i]]),
        values[i],
        @"fileNameIsText should be %@ for %@",
        [values[i] boolValue] ? @"true" : @"false",
        keys[i]);
}

@end
