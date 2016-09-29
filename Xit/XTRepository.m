#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import "XTConstants.h"
#import "Xit-Swift.h"
#import <ObjectiveGit/ObjectiveGit.h>

NSString *XTErrorOutputKey = @"output";
NSString *XTErrorArgsKey = @"args";
NSString *XTPathsKey = @"paths";

NSString *XTErrorDomainXit = @"Xit", *XTErrorDomainGit = @"git";

NSString * const XTRepositoryChangedNotification = @"RepoChanged";
NSString * const XTRepositoryRefsChangedNotification = @"RefsChanged";
NSString * const XTRepositoryIndexChangedNotification = @"IndexChanged";
NSString * const XTRepositoryHeadChangedNotification = @"HeadChanged";


@interface XTRepository ()

@property(readwrite) XTRepositoryWatcher *watcher;
@property(readwrite) BOOL isShutDown;
@property(readwrite) XTConfig *config;

@end

@interface XTRepository (CurrentBranch)

- (NSString*)calculateCurrentBranch;

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

- (nullable instancetype)initWithURL:(NSURL *)url
{
  self = [super init];
  if (self != nil) {
    NSError *error = nil;

    _gtRepo = [[GTRepository alloc] initWithURL:url error:&error];
    if (error != nil)
      NSLog(@"%@", error.description);
    _gitCMD = [self.class gitPath];
    _repoURL = url;
    NSMutableString *qName =
        [NSMutableString stringWithString:@"com.xit.queue."];
    [qName appendString:url.path];
    _queue = dispatch_queue_create(
        [qName cStringUsingEncoding:NSASCIIStringEncoding],
        DISPATCH_QUEUE_SERIAL);
    _diffCache = [[NSCache alloc] init];
    
    if (_gtRepo != nil) {
      self.watcher = [[XTRepositoryWatcher alloc] initWithRepository:self];
      self.config = [[XTConfig alloc] initWithRepository:self];
      
      [[NSNotificationCenter defaultCenter]
          addObserverForName:XTRepositoryRefsChangedNotification
                      object:self
                       queue:nil
                  usingBlock:^(NSNotification * _Nonnull note) {
        NSString *newBranch = [self calculateCurrentBranch];
        
        if (![_cachedBranch isEqualToString:newBranch]) {
          [self willChangeValueForKey:@"currentBranch"];
          _cachedBranch = newBranch;
          [self didChangeValueForKey:@"currentBranch"];
        }
      }];
    }
  }

  return self;
}

- (void)dealloc
{
  [self.watcher stop];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSURL*)gitDirectoryURL
{
  return _gtRepo.gitDirectoryURL;
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

// Make sure KVO notifications happen on the main thread
- (void)updateIsWriting:(BOOL)writing
{
  if (writing == self.isWriting)
    return;
  
  if ([NSThread isMainThread])
    self.isWriting = writing;
  else
    dispatch_sync(dispatch_get_main_queue(), ^{
      self.isWriting = writing;
    });
}

- (void)shutDown
{
  self.isShutDown = YES;
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
  if (error != NULL)
    *error = nil;

  @synchronized(self) {
    if (writes && self.isWriting) {
      if (error != NULL)
        *error = [NSError errorWithDomain:XTErrorDomainXit
                                     code:XTErrorWriteLock
                                 userInfo:nil];
      return nil;
    }
    [self updateIsWriting:YES];
    NSLog(@"****command = git %@", [args componentsJoinedByString:@" "]);
    NSTask *task = [[NSTask alloc] init];
    [[NSNotificationCenter defaultCenter] postNotificationName:XTTaskStartedNotification object:self];
    task.currentDirectoryPath = _repoURL.path;
    task.launchPath = _gitCMD;
    task.arguments = args;

    if (stdIn != nil) {
#if 0
      NSLog(@"**** stdin = %lu", stdIn.length);
#else
      NSLog(@"**** stdin = %lu\n%@", stdIn.length, stdIn);
#endif
      NSPipe *stdInPipe = [NSPipe pipe];
      [stdInPipe.fileHandleForWriting
          writeData:[stdIn dataUsingEncoding:NSUTF8StringEncoding]];
      [stdInPipe.fileHandleForWriting closeFile];
      task.standardInput = stdInPipe;
    }

    NSPipe *pipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];

    task.standardOutput = pipe;
    task.standardError = errorPipe;

    NSLog(@"task.currentDirectoryPath=%@", task.currentDirectoryPath);
    [task launch];
    NSData *output = [pipe.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];

    const int status = task.terminationStatus;
    NSLog(@"**** status = %d", status);

    if (status != 0) {
      NSString *string =
          [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
      NSData *errorOutput =
          [errorPipe.fileHandleForReading readDataToEndOfFile];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:XTTaskEndedNotification object:self];
    [self updateIsWriting:NO];
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

  id unresolved = gtRef.unresolvedTarget;

  if (![unresolved isKindOfClass:[GTReference class]])
    return reference;
  return [(GTReference*)unresolved name];
}

/// Returns kEmptyTreeHash if the repository is empty, otherwise "HEAD"
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
  return object.SHA;
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

- (NSString*)headSHA
{
  return [self shaForRef:[self headRef]];
}

- (NSArray<NSString*>*)remoteNames
{
  NSArray<NSString*> *result = [_gtRepo remoteNamesWithError:NULL];
  
  if (result == nil)
    result = @[];
  return result;
}

- (NSData*)contentsOfFile:(NSString*)filePath
                 atCommit:(NSString*)commitSHA
                    error:(NSError**)error
{
  GTCommit *commit = [self.gtRepo lookUpObjectBySHA:commitSHA error:error];

  if (![commit isKindOfClass:[GTCommit class]]) {
    if (*error == nil)
      *error = [NSError errorWithDomain:XTErrorDomainXit
                                   code:XTErrorUnexpectedObject
                               userInfo:nil];
    return nil;
  }

  GTTree *tree = commit.tree;
  GTTreeEntry *entry = [tree entryWithPath:filePath error:error];
  GTBlob *blob = (GTBlob*)[entry GTObject:error];

  if (![blob isKindOfClass:[GTBlob class]]) {
    if (*error == nil)
      *error = [NSError errorWithDomain:XTErrorDomainXit
                                   code:XTErrorUnexpectedObject
                               userInfo:nil];
    return nil;
  }
  return blob.data;
}

- (NSData*)contentsOfStagedFile:(NSString*)filePath
                          error:(NSError**)error
{
  GTIndex *index = [self.gtRepo indexWithError:error];
  
  if (index == nil)
    return nil;
  // GTRepository returns any cached index object it had, so it may need
  // to be reloaded.
  if (![index refresh:error])
    return nil;
  
  GTIndexEntry *entry = [index entryWithPath:filePath error:error];
  GTBlob *blob = (GTBlob*)[entry GTObject:error];
  
  if (![blob isKindOfClass:[GTBlob class]]) {
    if (*error == nil)
      *error = [NSError errorWithDomain:XTErrorDomainXit
                                   code:XTErrorUnexpectedObject
                               userInfo:nil];
    return nil;
  }
  return blob.data;
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

@end
