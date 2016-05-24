#import <XCTest/XCTest.h>
#import "NSData+Encoding.h"

@interface NSData_EncodingTests : XCTestCase

@end

@implementation NSData_EncodingTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
  NSArray<NSString*> *fileNames = @[
      @"utf8", @"utf16",
      @"utf16be", @"utf16le",
      @"utf32be", @"utf32le",
      ];
  NSStringEncoding encodings[] = {
      NSUTF8StringEncoding,
      NSUTF16StringEncoding,
      NSUTF16BigEndianStringEncoding,
      NSUTF16LittleEndianStringEncoding,
      NSUTF32BigEndianStringEncoding,
      NSUTF32LittleEndianStringEncoding,
      };
  NSBundle *testBundle =
      [NSBundle bundleWithIdentifier:@"com.uncommonplace.XitTests"];
  
  for (NSUInteger i = 0; i < fileNames.count; ++i) {
    NSURL *fileURL = [testBundle URLForResource:fileNames[i]
                                  withExtension:@"txt"];
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    
    XCTAssertNotNil(fileURL);
    XCTAssertNotNil(fileData);
    XCTAssertEqual([fileData sniffTextEncoding], encodings[i]);
  }
}

@end
