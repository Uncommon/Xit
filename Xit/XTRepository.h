#import <Foundation/Foundation.h>

extern NSString *XTRepositoryChangedNotification;
extern NSString *XTErrorOutputKey;
extern NSString *XTErrorArgsKey;
extern NSString *XTPathsKey;

@class GTRepository;

@interface XTRepository : NSObject {
 @private
  // The use of Objective Git should generally be considered an implementation
  // detail that should not be exposed to other classes.
  GTRepository *gtRepo;
  NSURL *repoURL;
  NSString *gitCMD;
  NSString *selectedCommit;
  NSString *cachedHeadRef, *cachedHeadSHA, *cachedBranch;
  NSCache *diffCache;
  NSDictionary *refsIndex;
  FSEventStreamRef stream;
  dispatch_queue_t queue;
  NSMutableArray *activeTasks;
}

- (id)initWithURL:(NSURL*)url;
- (void)getCommitsWithArgs:(NSArray*)logArgs
    enumerateCommitsUsingBlock:(void (^)(NSString*))block
                         error:(NSError**)error;

// Avoid calling these from outside XTRepository. Instead, add methods to
// +Commands or +Parsing.
// Returns command output on success, or nil on failure.
- (NSData*)executeGitWithArgs:(NSArray*)args
                       writes:(BOOL)writes
                        error:(NSError**)error;
- (NSData*)executeGitWithArgs:(NSArray*)args
                    withStdIn:(NSString*)stdIn
                       writes:(BOOL)writes
                        error:(NSError**)error;
- (BOOL)executeWritingBlock:(BOOL (^)())block;

- (BOOL)hasHeadReference;
- (NSString*)parentTree;
- (NSString*)headRef;
- (NSString*)headSHA;
- (NSString*)shaForRef:(NSString*)ref;

- (NSData*)contentsOfFile:(NSString*)filePath atCommit:(NSString*)commit;

- (void)initializeEventStream;
- (void)start;
- (void)stop;
- (void)reloadPaths:(NSArray*)paths;
- (void)addReloadObserver:(id)observer selector:(SEL)selector;

- (void)executeOffMainThread:(void (^)())block;
- (void)addTask:(NSTask*)task;
- (void)removeTask:(NSTask*)task;

@property(readonly) GTRepository *gtRepo;
@property(copy) NSString *selectedCommit;
@property(strong) NSDictionary *refsIndex;
@property(readonly) dispatch_queue_t queue;
@property(readonly) NSMutableArray *activeTasks;
@property(readonly) NSURL *repoURL;
@property(readonly) BOOL isWriting;

@end

// An empty tree will always have this hash.
#define kEmptyTreeHash @"4b825dc642cb6eb9a060e54bf8d69288fbee4904"

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[]);
