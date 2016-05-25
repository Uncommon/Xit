#import <Foundation/Foundation.h>

extern NSString *XTRepositoryChangedNotification;
extern NSString *XTErrorOutputKey;
extern NSString *XTErrorArgsKey;
extern NSString *XTPathsKey;

@class GTRepository;

/**
  XTRepository represents the application's interface to the Git repository.
  Operations may be implemented by executing Git itself, or by using libgit2.
 */
@interface XTRepository : NSObject {
 @private
  // The use of Objective Git should generally be considered an implementation
  // detail that should not be exposed to other classes.
  GTRepository *_gtRepo;
  NSURL *_repoURL;
  NSString *_gitCMD;
  NSString *_cachedHeadRef, *_cachedHeadSHA, *_cachedBranch;
  NSCache *_diffCache;
  FSEventStreamRef _stream;
}

- (id)initWithURL:(NSURL*)url;
- (void)getCommitsWithArgs:(NSArray*)logArgs
    enumerateCommitsUsingBlock:(void (^)(NSString*))block
                         error:(NSError**)error;

/**
  Avoid calling these from outside XTRepository. Instead, add methods to
  +Commands or +Parsing.
  @returns command output on success, or nil on failure.
 */
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
- (NSData*)contentsOfStagedFile:(NSString*)filePath;

- (void)addReloadObserver:(id)observer selector:(SEL)selector;

/**
 If called on the main thread, executes \a block on the repository's dispatch
 queue. If called on another thread, \a block is executed synchronously.
 */
- (void)executeOffMainThread:(void (^)())block;
/**
  After this is called, future calls to \a executeOffMainThread: from the main
  thread will be ignored.
 */
- (void)shutDown;

- (void)addTask:(NSTask*)task;
- (void)removeTask:(NSTask*)task;

@property(readonly) GTRepository *gtRepo;
@property(strong) NSDictionary *refsIndex;
@property(readonly) dispatch_queue_t queue;
@property(readonly) NSMutableArray *activeTasks;
@property(readonly) NSURL *repoURL;
@property(readonly) NSURL *gitDirectoryURL;
@property(readonly) BOOL isWriting;
@property(readonly) BOOL isShutDown;

@end

// An empty tree will always have this hash.
#define kEmptyTreeHash @"4b825dc642cb6eb9a060e54bf8d69288fbee4904"

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[]);
