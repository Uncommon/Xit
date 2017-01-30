#import <XCTest/XCTest.h>
#import <WebKit/WebKit.h>
#import "XTCommitHeaderViewController.h"
#import "XTRepository+Parsing.h"
#include "CFRunLoop+Extensions.h"

NSDate *authorDate = nil;
NSDate *commitDate = nil;

@interface XTCommitHeaderTest : XCTestCase
{
  CFRunLoopRef runLoop;
}

@end


@interface XTCommitHeaderViewController (Test)

@property (readonly, copy) NSString *generateHeaderHTML;

@end


@interface FakeGTRepository : NSObject

- (id)lookUpObjectBySHA:(NSString*)sha error:(NSError**)error;

@end


@interface FakeCommit : NSObject

@property NSString *message, *messageSummary;
@property NSString *shortSHA, *SHA;
@property NSString *authorName, *authorEmail;
@property NSString *committerName, *committerEmail;

@end


@interface FakeRepository : NSObject

@property (readonly, strong) FakeGTRepository *gtRepo;

@end


@implementation XTCommitHeaderTest

- (void)setUp
{
  authorDate = [NSDate date];
  commitDate = [NSDate dateWithTimeInterval:5000 sinceDate:authorDate];
}

- (void)progressFinished:(NSNotification*)note
{
  CFRunLoopStop(runLoop);
}

- (void)testHTML
{
  WebView *webView = [[WebView alloc] init];
  XTCommitHeaderViewController *hvc = [[XTCommitHeaderViewController alloc] init];
  FakeRepository *fakeRepo = [[FakeRepository alloc] init];
  FakeCommit *commit = [[FakeCommit alloc] init];

  webView.frameLoadDelegate = hvc;
  webView.UIDelegate = hvc;
  hvc.webView = webView;
  hvc.repository = (XTRepository*)fakeRepo;
  hvc.commitSHA = @"blahblah";
  
  commit.authorName = @"Guy One";
  commit.authorEmail = @"guy1@example.com";
  commit.committerName = @"Guy Two";
  commit.committerEmail = @"guy2@example.com";
  commit.message = @"Example message";

  // The result doesn't include the enclosing html tags, so neither does the
  // reference file.
  NSString *html = [hvc generateHeaderHTML:(XTCommit*)commit];
  NSBundle *testBundle =
      [NSBundle bundleWithIdentifier:@"com.uncommonplace.XitTests"];
  NSURL *expectedURL = [testBundle URLForResource:@"expected header"
                                    withExtension:@"html"];
  NSStringEncoding encoding;
  NSError *error = nil;
  NSString *expectedHtmlTemplate =
      [NSString stringWithContentsOfURL:expectedURL
                           usedEncoding:&encoding
                                  error:&error];
  NSDateFormatter *dateFormatter = [XTCommitHeaderViewController dateFormatter];
  NSString *expectedHtml = [NSString stringWithFormat:expectedHtmlTemplate,
      [dateFormatter stringFromDate:authorDate],
      [dateFormatter stringFromDate:commitDate]];
  
  XCTAssertNil(error);

  NSArray *lines = [html componentsSeparatedByString:@"\n"];
  NSArray *expectedLines = [expectedHtml componentsSeparatedByString:@"\n"];

  // Some differences may be due to changes in WebKit.
  XCTAssertEqual([lines count], [expectedLines count]);
  for (NSUInteger i = 0; i < lines.count; ++i)
    XCTAssertEqualObjects(lines[i], expectedLines[i],
                          @"line %lu", (unsigned long)i);
}

@end

@implementation FakeRepository

- (FakeGTRepository*)gtRepo
{
  return [[FakeGTRepository alloc] init];
}

@end

@implementation FakeGTRepository

- (id)lookUpObjectBySHA:(NSString*)sha error:(NSError**)error
{
  FakeCommit *commit = [[FakeCommit alloc] init];

  if ([sha isEqualToString:@"111111"])
    commit.messageSummary = @"Alphabet<>";
  if ([sha isEqualToString:@"222222"])
    commit.messageSummary = @"Broccoli&";
  if ([sha isEqualToString:@"333333"])
    commit.messageSummary = @"Cypress";
  commit.shortSHA = sha;
  commit.SHA = sha;
  return commit;
}

@end

@implementation FakeCommit

- (NSArray*)parentSHAs
{
  return @[ @"111111", @"222222", @"333333" ];
}

- (NSDate*)authorDate
{
  return authorDate;
}

- (NSDate*)commitDate
{
  return commitDate;
}

@end
