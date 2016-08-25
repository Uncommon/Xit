#import "XTRepositoryWatcher.h"
#import "XTRepository.h"
#import "Xit-Swift.h"

NSString * const XTRepositoryChangedNotification = @"RepoChanged";
NSString * const XTRepositoryRefsChangedNotification = @"RefsChanged";
NSString * const XTRepositoryIndexChangedNotification = @"IndexChanged";

NSString * const XTAddedRefsKey = @"addedRefs";
NSString * const XTDeletedRefsKey = @"deletedRefs";
NSString * const XTChangedRefsKey = @"changedRefs";


void EventStreamCallback(
    ConstFSEventStreamRef streamRef, void *userData,
    size_t numEvents, void *eventPaths,
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[]);


@interface XTRepositoryWatcher ()

@property (weak) XTRepository *repo;
@property FSEventStreamRef stream;
@property (nonatomic) NSDate *lastIndexChange;
@property NSDictionary<NSString*, GTOID*> *refsCache;

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
    self.refsCache = [self indexRefs:[repo allRefs]];
    [self startEventStream];
  }
  return self;
}

-(void)dealloc
{
  if (self.stream != NULL) {
    FSEventStreamStop(self.stream);
    FSEventStreamInvalidate(self.stream);
    FSEventStreamRelease(self.stream);
  }
}

-(NSDictionary<NSString*, GTOID*>*)indexRefs:(NSArray<NSString*>*)refs
{
  NSDictionary<NSString*, GTOID*> *result =
      [NSMutableDictionary dictionaryWithCapacity:refs.count];

  for (NSString *ref in refs) {
    GTOID *oid = [GTOID oidWithSHA:[self.repo shaForRef:ref]];
    
    if (oid != nil)
      [result setValue:oid forKey:ref];
  }

  return result;
}

-(void)setLastIndexChange:(NSDate*)lastIndexChange
{
  _lastIndexChange = lastIndexChange;
  [[NSNotificationCenter defaultCenter]
      postNotificationName:XTRepositoryIndexChangedNotification
                    object:self.repo];
}

-(void)startEventStream
{
  NSString *path = self.repo.gitDirectoryURL.path;
  NSArray *paths = @[ path ];
  FSEventStreamContext context = {
      0, (__bridge void * _Nullable)(self),
      NULL, NULL, NULL };
  const CFTimeInterval latency = 0.5;

  self.stream = FSEventStreamCreate(
      kCFAllocatorDefault,
      EventStreamCallback,
      &context,
      (__bridge CFArrayRef)paths,
      kFSEventStreamEventIdSinceNow,
      latency,
      kFSEventStreamCreateFlagUseCFTypes |
      kFSEventStreamCreateFlagNoDefer);
  if (self.stream != NULL) {
    FSEventStreamScheduleWithRunLoop(self.stream,
                                     CFRunLoopGetMain(),
                                     kCFRunLoopDefaultMode);
    FSEventStreamStart(self.stream);
  }
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

-(void)checkRefs:(NSArray<NSString*>*)paths
{
  NSString * const headsSubpath = @"refs/heads/";
  BOOL refsChanged = NO;

  for (NSString *path in paths) {
    if ([path hasSuffix:headsSubpath] ||
        [[path stringByDeletingLastPathComponent] hasSuffix:headsSubpath]) {
      refsChanged = YES;
      break;
    }
  }
  if (!refsChanged)
    return;

  NSDictionary<NSString*, GTOID*> *newRefCache =
      [self indexRefs:[self.repo allRefs]];
  NSSet<NSString*> *newKeys = [NSSet setWithArray:newRefCache.allKeys],
                   *oldKeys = [NSSet setWithArray:self.refsCache.allKeys];
  NSMutableSet<NSString*> *addedRefs = [newKeys mutableCopy],
                          *deletedRefs = [oldKeys mutableCopy],
                          *changedRefs = [newKeys mutableCopy];
  
  [addedRefs minusSet:oldKeys];
  [deletedRefs minusSet:newKeys];
  [changedRefs minusSet:addedRefs];
  [changedRefs filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
      id  _Nonnull key,
      NSDictionary<NSString *,id> * _Nullable bindings) {
    GTOID *oldOID = self.refsCache[key],
    *newOID = [GTOID oidWithSHA:[self.repo shaForRef:key]];
    
    return ![oldOID isEqual:newOID];
  }]];
  
  NSMutableDictionary<NSString*, NSSet*> *refChanges =
      [NSMutableDictionary dictionaryWithCapacity:3];
  
  if (addedRefs.count > 0)
    [refChanges setObject:addedRefs forKey:XTAddedRefsKey];
  if (deletedRefs.count > 0)
    [refChanges setObject:deletedRefs forKey:XTDeletedRefsKey];
  if (changedRefs.count > 0)
    [refChanges setObject:changedRefs forKey:XTChangedRefsKey];
  
  if (refChanges.count > 0) {
    [self.repo rebuildRefsIndex];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:XTRepositoryRefsChangedNotification
                      object:self.repo
                    userInfo:refChanges];
  }
  self.refsCache = newRefCache;
}

-(void)observeEvents:(NSArray<NSString*>*)paths
{
  [self checkIndex];
  [self checkRefs:paths];
  
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
