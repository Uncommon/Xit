#import "XTCommitHeaderTest.h"
#import "XTCommitHeaderViewController.h"
#import "XTRepository+Parsing.h"

@interface XTCommitHeaderViewController (Test)

- (NSString*)generateHeaderHTML;

@end

@interface FakeRepository : NSObject

- (BOOL)parseCommit:(NSString *)ref
         intoHeader:(NSDictionary **)header
            message:(NSString **)message
              files:(NSArray **)files;

@end

@implementation XTCommitHeaderTest

- (void)testHTML
{
  XTCommitHeaderViewController *hvc = [[XTCommitHeaderViewController alloc] init];
  FakeRepository *fakeRepo = [[FakeRepository alloc] init];

  [hvc setRepository:(XTRepository*)fakeRepo commit:@"blahblah"];

  NSString *html = [hvc generateHeaderHTML];
}

@end

@implementation FakeRepository

- (BOOL)parseCommit:(NSString *)ref
         intoHeader:(NSDictionary **)header
            message:(NSString **)message
              files:(NSArray **)files
{
  NSDate *authorDate = [NSDate date];
  NSDate *commitDate = [NSDate date];
  *header = [NSDictionary dictionaryWithObjectsAndKeys:
      @"Guy One", XTAuthorNameKey,
      @"guy1@example.com", XTAuthorEmailKey,
      authorDate, XTAuthorDateKey,
      @"Guy Two", XTCommitterNameKey,
      @"guy2@example.com", XTCommitterEmailKey,
      commitDate, XTCommitterDateKey,
      [NSArray array], XTParentSHAsKey,
      [NSArray array], XTRefsKey,
      nil];
  *message = @"Example message";
  if (files != NULL)
    *files = [NSArray array];
  return YES;
}

@end