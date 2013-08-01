#import "XTTest.h"
#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"

@implementation XTTest

- (void)setUp
{
  [super setUp];

  repoPath = [NSString stringWithFormat:@"%@testrepo", NSTemporaryDirectory()];
  repository = [self createRepo:repoPath];

  [self addInitialRepoContent];

  NSLog(@"setUp ok");
}

- (void)tearDown
{
  [self waitForRepoQueue];

  NSFileManager *defaultManager = [NSFileManager defaultManager];
  [defaultManager removeItemAtPath:repoPath error:nil];
  [defaultManager removeItemAtPath:remoteRepoPath error:nil];

  if ([defaultManager fileExistsAtPath:repoPath]) {
    STFail(@"tearDown %@ FAIL!!", repoPath);
  }

  if ([defaultManager fileExistsAtPath:remoteRepoPath]) {
    STFail(@"tearDown %@ FAIL!!", remoteRepoPath);
  }

  NSLog(@"tearDown ok");

  [super tearDown];
}

- (void)makeRemoteRepo
{
  remoteRepoPath =
      [NSString stringWithFormat:@"%@remotetestrepo", NSTemporaryDirectory()];
  remoteRepository = [self createRepo:remoteRepoPath];
}

- (void)addInitialRepoContent
{
  STAssertTrue([self commitNewTextFile:@"file1.txt" content:@"some text"], nil);
  file1Path = [repoPath stringByAppendingPathComponent:@"file1.txt"];
}

- (BOOL)commitNewTextFile:(NSString *)name content:(NSString *)content
{
  return [self commitNewTextFile:name content:content inRepository:repository];
}

- (BOOL)commitNewTextFile:(NSString *)name
                  content:(NSString *)content
             inRepository:(XTRepository *)repo
{
  NSString *basePath = [repo.repoURL path];
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
    STFail(@"initializeRepository '%@' FAIL!!", repoName);
  }

  if (![fileManager
          fileExistsAtPath:[NSString stringWithFormat:@"%@/.git", repoName]]) {
    STFail(@"%@/.git NOT Found!!", repoName);
  }

  return repo;
}

- (void)waitForQueue:(dispatch_queue_t)queue
{
  // Some queued tasks need to also perform tasks on the main thread, so
  // simply waiting on the queue could cause a deadlock.
  const CFRunLoopRef loop = CFRunLoopGetCurrent();
  __block BOOL keepLooping = YES;

  // Loop because something else might quit the run loop.
  do {
    CFRunLoopPerformBlock(loop, kCFRunLoopCommonModes, ^{
      dispatch_async(queue, ^{
        CFRunLoopStop(loop);
        keepLooping = NO;
      });
    });
    CFRunLoopRun();
  } while (keepLooping);
}

- (void)waitForRepoQueue
{
  [self waitForQueue:repository.queue];
}

- (BOOL)writeTextToFile1:(NSString *)text
{
  NSError *error;

  [text writeToFile:file1Path
         atomically:YES
           encoding:NSASCIIStringEncoding
              error:&error];
  return error == nil;
}

@end
