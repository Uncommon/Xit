#import "XTRepository.h"
#import "XTConstants.h"
#import <ObjectiveGit/ObjectiveGit.h>

NSString *XTRepositoryChangedNotification = @"xtrepochanged";
NSString *XTErrorOutputKey = @"output";
NSString *XTErrorArgsKey = @"args";
NSString *XTPathsKey = @"paths";

NSString *XTErrorDomainXit = @"Xit", *XTErrorDomainGit = @"git";

@interface XTRepository ()

@property(readwrite) BOOL isWriting;
@property(readwrite) BOOL isShutDown;

@end

@implementation XTRepository


+ (NSString *)gitPath
{
  NSArray *paths = @[ @"/usr/bin/git", @"/usr/local/git/bin/git" ];

  for (NSString *path in paths) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
      return path;
  }
  return nil;
}

- (id)initWithURL:(NSURL *)url
{
  self = [super init];
  if (self != nil) {
    NSError *error = nil;

    _gtRepo = [[GTRepository alloc] initWithURL:url error:&error];
    if (error != nil) {
      // TODO: Make sure we know why it failed.
      // Assume repo hasn't been created yet, and initializeRepository will
      // be called later.
    }
    _gitCMD = [XTRepository gitPath];
    _repoURL = url;
    NSMutableString *qName =
        [NSMutableString stringWithString:@"com.xit.queue."];
    [qName appendString:[url path]];
    _queue = dispatch_queue_create(
        [qName cStringUsingEncoding:NSASCIIStringEncoding],
        DISPATCH_QUEUE_SERIAL);
    _activeTasks = [NSMutableArray array];
    _diffCache = [[NSCache alloc] init];
  }

  return self;
}

- (BOOL)executeWritingBlock:(BOOL (^)())block;
{
  BOOL result = NO;

  @synchronized(self) {
    if (self.isWriting)
      return NO;
    self.isWriting = YES;
    result = block();
    self.isWriting = NO;
  }
  return result;
}

- (void)executeOffMainThread:(void (^)())block
{
  if ([NSThread isMainThread]) {
    if (!self.isShutDown)
      dispatch_async(_queue, block);
  } else {
    block();
  }
}

- (void)shutDown
{
  self.isShutDown = YES;
}

- (void)addTask:(NSTask *)task
{
  [self willChangeValueForKey:@"activeTasks"];
  @synchronized(_activeTasks) {
    [_activeTasks addObject:task];
  }
  [self didChangeValueForKey:@"activeTasks"];
}

- (void)removeTask:(NSTask *)task
{
  @synchronized(_activeTasks) {
    if (![_activeTasks containsObject:task])
      return;
    [self willChangeValueForKey:@"activeTasks"];
    [_activeTasks removeObject:task];
  }
  [self didChangeValueForKey:@"activeTasks"];
}

- (void)getCommitsWithArgs:(NSArray *)logArgs
    enumerateCommitsUsingBlock:(void (^)(NSString *))block
                         error:(NSError **)error
{
  if (_repoURL == nil) {
    if (error != NULL)
      *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                   code:fnfErr
                               userInfo:nil];
    return;
  }
  if (![self hasHeadReference])
    return;  // There are no commits.

  NSMutableArray *args = [NSMutableArray arrayWithArray:logArgs];

  [args insertObject:@"log" atIndex:0];
  [args insertObject:@"-z" atIndex:1];
  NSData *zero = [NSData dataWithBytes:"" length:1];

  NSLog(@"****command = git %@", [args componentsJoinedByString:@" "]);
  NSTask *task = [[NSTask alloc] init];
  [self addTask:task];
  [task setCurrentDirectoryPath:[_repoURL path]];
  [task setLaunchPath:_gitCMD];
  [task setArguments:args];

  NSPipe *pipe = [NSPipe pipe];
  [task setStandardOutput:pipe];
  [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];

  [task launch];
  NSMutableData *output = [NSMutableData data];

  BOOL end = NO;
  while (!end) {
    NSData *availableData = [[pipe fileHandleForReading] availableData];
    [output appendData:availableData];

    end = (([availableData length] == 0) && ![task isRunning]);
    if (end)
      [output appendData:zero];

    NSRange searchRange = NSMakeRange(0, [output length]);
    NSRange zeroRange = [output rangeOfData:zero options:0 range:searchRange];
    while (zeroRange.location != NSNotFound) {
      NSRange commitRange = NSMakeRange(
          searchRange.location, (zeroRange.location - searchRange.location));
      NSData *commit = [output subdataWithRange:commitRange];
      NSString *str =
          [[NSString alloc] initWithData:commit encoding:NSUTF8StringEncoding];
      if (str != nil)
        block(str);
      searchRange = NSMakeRange(zeroRange.location + 1,
                                [output length] - (zeroRange.location + 1));
      zeroRange = [output rangeOfData:zero options:0 range:searchRange];
    }
    output = [NSMutableData dataWithData:[output subdataWithRange:searchRange]];
  }

  int status = [task terminationStatus];
  NSLog(@"**** status = %d", status);

  if (status != 0) {
    NSString *string =
        [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    if (error != NULL) {
      *error = [NSError errorWithDomain:XTErrorDomainGit
                                   code:status
                               userInfo:@{XTErrorOutputKey : string}];
    }
  }
  [self removeTask:task];
}

- (NSData *)executeGitWithArgs:(NSArray *)args
                        writes:(BOOL)writes
                         error:(NSError **)error
{
  return [self executeGitWithArgs:args
                        withStdIn:nil
                           writes:writes
                            error:error];
}

- (NSData *)executeGitWithArgs:(NSArray *)args
                     withStdIn:(NSString *)stdIn
                        writes:(BOOL)writes
                         error:(NSError **)error
{
  if (_repoURL == nil)
    return nil;

  @synchronized(self) {
    if (writes && self.isWriting) {
      if (error != NULL)
        *error = [NSError errorWithDomain:XTErrorDomainXit
                                     code:XTErrorWriteLock
                                 userInfo:nil];
      return nil;
    }
    self.isWriting = YES;
    NSLog(@"****command = git %@", [args componentsJoinedByString:@" "]);
    NSTask *task = [[NSTask alloc] init];
    [self addTask:task];
    [task setCurrentDirectoryPath:[_repoURL path]];
    [task setLaunchPath:_gitCMD];
    [task setArguments:args];

    if (stdIn != nil) {
#if 0
      NSLog(@"**** stdin = %lu", stdIn.length);
#else
      NSLog(@"**** stdin = %lu\n%@", stdIn.length, stdIn);
#endif
      NSPipe *stdInPipe = [NSPipe pipe];
      [[stdInPipe fileHandleForWriting]
          writeData:[stdIn dataUsingEncoding:NSUTF8StringEncoding]];
      [[stdInPipe fileHandleForWriting] closeFile];
      [task setStandardInput:stdInPipe];
    }

    NSPipe *pipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];

    [task setStandardOutput:pipe];
    [task setStandardError:errorPipe];

    NSLog(@"task.currentDirectoryPath=%@", task.currentDirectoryPath);
    [task launch];
    NSData *output = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];

    int status = [task terminationStatus];
    NSLog(@"**** status = %d", status);

    if (status != 0) {
      NSString *string =
          [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
      NSData *errorOutput =
          [[errorPipe fileHandleForReading] readDataToEndOfFile];
      NSString *errorString =
          [[NSString alloc] initWithData:errorOutput encoding:NSUTF8StringEncoding];
      NSLog(@"**** output = %@", string);
      NSLog(@"**** error = %@", errorString);
      if (error != NULL) {
        NSDictionary *info =
            @{ XTErrorOutputKey:string,
               XTErrorArgsKey:[args componentsJoinedByString:@" "] };

        *error = [NSError errorWithDomain:@"git" code:status userInfo:info];
      }
      output = nil;
    }
    [self removeTask:task];
    self.isWriting = NO;
    return output;
  }
}

- (BOOL)hasHeadReference
{
  NSError *error = nil;

  return [_gtRepo headReferenceWithError:&error] != nil;
}

- (NSString *)parseSymbolicReference:(NSString *)reference
{
  NSError *error = nil;
  GTReference *gtRef = [_gtRepo lookUpReferenceWithName:reference error:&error];

  if (error != nil)
    return nil;

  id unresolved = [gtRef unresolvedTarget];

  if (![unresolved isKindOfClass:[GTReference class]])
    return reference;
  return [[gtRef unresolvedTarget] name];
}

// Returns kEmptyTreeHash if the repository is empty, otherwise "HEAD"
- (NSString *)parentTree
{
  return [self hasHeadReference] ? @"HEAD" : kEmptyTreeHash;
}

- (NSString *)shaForRef:(NSString *)ref
{
  if (ref == nil)
    return nil;

  NSError *error = nil;
  GTObject *object = [_gtRepo lookUpObjectByRevParse:ref error:&error];

  if (error != nil)
    return nil;
  return [object SHA];
}

- (NSString *)headRef
{
  @synchronized(self) {
    if (_cachedHeadRef == nil) {
      NSString *head = [self parseSymbolicReference:@"HEAD"];

      if ([head hasPrefix:@"refs/heads/"])
        _cachedHeadRef = head;
      else
        _cachedHeadRef = @"HEAD";

      _cachedHeadSHA = [self shaForRef:_cachedHeadRef];
    }
  }
  return _cachedHeadRef;
}

- (NSString *)headSHA
{
  return [self shaForRef:[self headRef]];
}

- (NSData*)contentsOfFile:(NSString*)filePath atCommit:(NSString*)commitSHA
{
  if ((filePath == nil) || (commitSHA == nil))
    return nil;

  NSError *error = nil;
  GTCommit *commit = [self.gtRepo lookUpObjectBySHA:commitSHA error:&error];

  if (![commit isKindOfClass:[GTCommit class]])
    return nil;

  GTTree *tree = commit.tree;
  GTTreeEntry *entry = [tree entryWithPath:filePath error:&error];
  GTBlob *blob = (GTBlob*)[entry GTObject:&error];

  if (![blob isKindOfClass:[GTBlob class]])
    return nil;
  return blob.data;
}

- (NSData*)contentsOfStagedFile:(NSString*)filePath
{
  NSError *error = nil;
  GTIndex *index = [self.gtRepo indexWithError:&error];
  
  // GTRepository returns any cached index object it had, so it may need
  // to be reloaded.
  [index refresh:&error];
  
  GTIndexEntry *entry = [index entryWithPath:filePath error:&error];
  GTBlob *blob = (GTBlob*)[entry GTObject:&error];
  
  if (![blob isKindOfClass:[GTBlob class]])
    return nil;
  return blob.data;
}

// XXX tmp
- (void)start
{
  [self initializeEventStream];
}

- (void)stop
{
  if (_stream != NULL) {
    FSEventStreamStop(_stream);
    FSEventStreamInvalidate(_stream);
  }
}

#pragma mark - monitor file system
- (void)initializeEventStream
{
  if (_repoURL == nil)
    return;
  NSString *myPath = [[_repoURL URLByAppendingPathComponent:@".git"] path];
  NSArray *pathsToWatch = @[ myPath ];
  void *repoPointer = (__bridge void *)self;
  FSEventStreamContext context = {0, repoPointer, NULL, NULL, NULL};
  NSTimeInterval latency = 3.0;

  _stream = FSEventStreamCreate(
      kCFAllocatorDefault, &fsevents_callback, &context,
      (__bridge CFArrayRef) pathsToWatch, kFSEventStreamEventIdSinceNow,
      (CFAbsoluteTime) latency, kFSEventStreamCreateFlagUseCFTypes);

  FSEventStreamScheduleWithRunLoop(_stream, CFRunLoopGetCurrent(),
                                   kCFRunLoopDefaultMode);
  FSEventStreamStart(_stream);
}

- (void)reloadPaths:(NSArray *)paths
{
  for (NSString *path in paths)
    if ([path hasPrefix:@".git/"]) {
      _cachedBranch = nil;
      break;
    }

  NSDictionary *info = @{XTPathsKey : paths};

  [[NSNotificationCenter defaultCenter]
      postNotificationName:XTRepositoryChangedNotification
                    object:self
                  userInfo:info];
}

// A convenience method for adding to the default notification center.
- (void)addReloadObserver:(id)observer selector:(SEL)selector
{
  [[NSNotificationCenter defaultCenter]
      addObserver:observer
         selector:selector
             name:XTRepositoryChangedNotification
           object:self];
}

int event = 0;

void fsevents_callback(ConstFSEventStreamRef streamRef, void *userData,
                       size_t numEvents, void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[])
{
  XTRepository *repo = (__bridge XTRepository *)userData;

  ++event;

  NSMutableArray *paths = [NSMutableArray arrayWithCapacity:numEvents];
  for (size_t i = 0; i < numEvents; i++) {
    NSString *path = ((__bridge NSArray *)eventPaths)[i];
    NSRange r = [path rangeOfString:@".git" options:NSBackwardsSearch];

    path = [path substringFromIndex:r.location];
    [paths addObject:path];
    NSLog(@"fsevent #%d\t%@", event, path);
  }

  [repo reloadPaths:paths];
}

@end
