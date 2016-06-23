#import "XTTest.h"
#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#include "XTQueueUtils.h"

@implementation XTTest

- (void)setUp
{
  [super setUp];

  // /tmp is actually a link to /private/tmp, which APIs like
  // NSTemporaryDirectory and -[NSString stringByResolvingSymlinksInPath]
  // deliberately ignore, but -[NSFileManager enumeratorAtURL] doesn't.
  self.repoPath = [@"/private" stringByAppendingPathComponent:
      [NSString stringWithFormat:@"%@testrepo", NSTemporaryDirectory()]];
  self.repository = [self createRepo:self.repoPath];

  [self addInitialRepoContent];

  NSLog(@"setUp ok");
}

- (void)tearDown
{
  [self waitForRepoQueue];

  NSFileManager *defaultManager = [NSFileManager defaultManager];
  [defaultManager removeItemAtPath:self.repoPath error:nil];
  [defaultManager removeItemAtPath:self.remoteRepoPath error:nil];

  if ([defaultManager fileExistsAtPath:self.repoPath]) {
    XCTFail(@"tearDown %@ FAIL!!", self.repoPath);
  }

  if ([defaultManager fileExistsAtPath:self.remoteRepoPath]) {
    XCTFail(@"tearDown %@ FAIL!!", self.remoteRepoPath);
  }

  NSLog(@"tearDown ok");

  [super tearDown];
}

- (NSString*)file1Name
{
  return @"file1.txt";
}

- (NSString*)file1Path
{
  return [self.repoPath stringByAppendingPathComponent:self.file1Name];
}

- (NSString*)addedName
{
  return @"added.txt";
}

- (NSString*)untrackedName
{
  return @"untracked.txt";
}

- (void)makeRemoteRepo
{
  self.remoteRepoPath =
      [NSString stringWithFormat:@"%@remotetestrepo", NSTemporaryDirectory()];
  self.remoteRepository = [self createRepo:self.remoteRepoPath];
}

- (void)addInitialRepoContent
{
  XCTAssertTrue([self commitNewTextFile:self.file1Name content:@"some text"]);
}

- (void)makeStash
{
  [self writeTextToFile1:@"stashy"];
  [self writeText:@"new" toFile:self.untrackedName];
  [self writeText:@"add" toFile:self.addedName];
  [self.repository stageFile:self.addedName];
  [self.repository saveStash:@"" includeUntracked:YES];
}

- (BOOL)commitNewTextFile:(NSString *)name content:(NSString *)content
{
  return [self commitNewTextFile:name
                         content:content
                    inRepository:self.repository];
}

- (BOOL)commitNewTextFile:(NSString *)name
                  content:(NSString *)content
             inRepository:(XTRepository *)repo
{
  NSString *basePath = repo.repoURL.path;
  NSString *filePath = [basePath stringByAppendingPathComponent:name];

  [content writeToFile:filePath
            atomically:YES
              encoding:NSASCIIStringEncoding
                 error:nil];

  if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    return NO;
  if (![repo stageFile:name])
    return NO;
  if (![repo commitWithMessage:[NSString stringWithFormat:@"new %@", name]
                         amend:NO
                   outputBlock:NULL
                         error:NULL])
    return NO;

  return YES;
}

- (XTRepository *)createRepo:(NSString *)repoName
{
  NSLog(@"[createRepo] repoName=%@", repoName);
  NSFileManager *fileManager = [NSFileManager defaultManager];

  // TODO: We need better error checking here!
  if ([fileManager fileExistsAtPath:repoName]) {
    [fileManager removeItemAtPath:repoName error:nil];
  }
  [fileManager createDirectoryAtPath:repoName
         withIntermediateDirectories:YES
                          attributes:nil
                               error:nil];

  NSURL *repoURL = [NSURL URLWithString:
          [NSString stringWithFormat:@"file://localhost%@", repoName]];

  XTRepository *repo = [[XTRepository alloc] initWithURL:repoURL];

  if (![repo initializeRepository]) {
    XCTFail(@"initializeRepository '%@' FAIL!!", repoName);
  }

  if (![fileManager
          fileExistsAtPath:[NSString stringWithFormat:@"%@/.git", repoName]]) {
    XCTFail(@"%@/.git NOT Found!!", repoName);
  }

  return repo;
}

- (void)waitForRepoQueue
{
  WaitForQueue(self.repository.queue);
  WaitForQueue(dispatch_get_main_queue());
}

- (BOOL)writeText:(NSString *)text toFile:(NSString *)path
{
  return [text writeToFile:[self.repoPath stringByAppendingPathComponent:path]
                atomically:YES
                  encoding:NSUTF8StringEncoding
                     error:nil];
}

- (BOOL)writeTextToFile1:(NSString *)text
{
  NSError *error;

  [text writeToFile:self.file1Path
         atomically:YES
           encoding:NSUTF8StringEncoding
              error:&error];
  return error == nil;
}

@end


@implementation XTFakeWinController

@end
