#import "XTRepositoryWatcher.h"
#import "XTRepository.h"


void EventStreamCallback(
    ConstFSEventStreamRef streamRef, void *userData,
    size_t numEvents, void *eventPaths,
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[]);

NSString * const XTRepositoryIndexChangedNotification = @"IndexChanged";


@interface XTRepositoryWatcher ()

@property (weak) XTRepository *repo;
@property FSEventStreamRef stream;
@property (nonatomic) NSDate *lastIndexChange;

@end


@implementation XTRepositoryWatcher

+(instancetype)watcherWithRepo:(XTRepository*)repo
{
  return [[self alloc] initWithRepo:repo];
}

-(instancetype)initWithRepo:(XTRepository*)repo
{
  self = [super init];
  if (self != nil) {
    self.repo = repo;
    self.lastIndexChange = [NSDate date];
    [self startEventStream];
  }
  return self;
}

-(void)dealloc
{
  if (self.stream != NULL)
    FSEventStreamRelease(self.stream);
}

-(void)setLastIndexChange:(NSDate*)lastIndexChange
{
  _lastIndexChange = lastIndexChange;
  [[NSNotificationCenter defaultCenter] postNotificationName:XTRepositoryIndexChangedNotification object:self.repo];
}

-(void)startEventStream
{
  NSString *path = [self.repo.repoURL.path
      stringByAppendingPathComponent:@".git"];
  NSArray *paths = @[ path ];
  FSEventStreamContext context = {
      0, (__bridge void * _Nullable)(self),
      NULL, NULL, NULL };

  self.stream = FSEventStreamCreate(
      kCFAllocatorDefault,
      EventStreamCallback,
      &context,
      (__bridge CFArrayRef)paths,
      kFSEventStreamEventIdSinceNow,
      1.0, kFSEventStreamCreateFlagUseCFTypes);
}

-(void)checkIndex
{
  NSString *indexPath =
      [self.repo.repoURL.path stringByAppendingPathComponent:@".git/index"];
  NSDictionary *indexAttributes = [[NSFileManager defaultManager]
      attributesOfItemAtPath:indexPath error:NULL];
  
  if (indexAttributes == nil)
    self.lastIndexChange = nil;
  else {
    NSDate *newMod = indexAttributes.fileModificationDate;
    
    if ((newMod != nil) &&
        ([self.lastIndexChange compare:newMod] != NSOrderedSame))
      self.lastIndexChange = newMod;
  }
}

-(void)observeEvents:(NSArray<NSString*>*)paths
{
  [self checkIndex];
  
  // Temporary until more specific notifications are done
  [[NSNotificationCenter defaultCenter]
      postNotificationName:XTRepositoryChangedNotification object:self.repo];
}

@end

void EventStreamCallback(
    ConstFSEventStreamRef streamRef, void *userData,
    size_t numEvents, void *eventPaths,
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[])
{
  XTRepositoryWatcher *watcher = (__bridge XTRepositoryWatcher*)userData;
  
  [watcher observeEvents:(__bridge NSArray*)eventPaths];
}
