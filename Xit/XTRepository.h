#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *XTErrorOutputKey;
extern NSString *XTErrorArgsKey;
extern NSString *XTPathsKey;

@class GTRepository;
@class XTConfig;
@class XTRepositoryWatcher;
@class XTWorkspaceWatcher;

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
}

- (nullable instancetype)initWithURL:(NSURL*)url;

/**
  Avoid calling these from outside XTRepository. Instead, add methods to
  +Commands or +Parsing.
  @returns command output on success, or nil on failure.
 */
- (NSData*)executeGitWithArgs:(NSArray*)args
                       writes:(BOOL)writes
                        error:(NSError**)error;
- (NSData*)executeGitWithArgs:(NSArray*)args
                    withStdIn:(nullable NSString*)stdIn
                       writes:(BOOL)writes
                        error:(NSError**)error;
- (BOOL)executeWritingBlock:(BOOL (^)())block;

- (nullable NSString*)shaForRef:(NSString*)ref;

- (nullable NSData*)contentsOfFile:(NSString*)filePath
                          atCommit:(NSString*)commit
                             error:(NSError**)error;
- (nullable NSData*)contentsOfStagedFile:(NSString*)filePath
                                   error:(NSError**)error;

- (void)refsChanged;
- (void)addReloadObserver:(id)observer selector:(SEL)selector;

/**
 If called on the main thread, executes \a block on the repository's dispatch
 queue. If called on another thread, \a block is executed synchronously.
 */
- (void)executeOffMainThread:(void (^)())block;
- (void)updateIsWriting:(BOOL)writing; // Private use
/**
  After this is called, future calls to \a executeOffMainThread: from the main
  thread will be ignored.
 */
- (void)shutDown;

@property(readonly) BOOL busy;
@property(readonly) BOOL hasHeadReference;
@property(readonly, copy) NSString *parentTree;
@property(readonly, copy) NSString *headRef;
@property(readonly, copy, nullable) NSString *headSHA;
@property(readonly, copy) NSArray<NSString*> *remoteNames;
@property(readonly) GTRepository *gtRepo;
@property(strong) NSDictionary<NSString*, NSArray<NSString*>*> *refsIndex;
@property(readonly) dispatch_queue_t queue;
@property(readonly) NSURL *repoURL;
@property(readonly) NSURL *gitDirectoryURL;
@property(readwrite) BOOL isWriting;  /// Other classes should only read
@property(readonly) BOOL isShutDown;

@property(readonly) XTRepositoryWatcher *repoWatcher;
@property(readonly) XTWorkspaceWatcher *workspaceWatcher;
@property(readonly) XTConfig *config;

@end

NS_ASSUME_NONNULL_END

// An empty tree will always have this hash.
#define kEmptyTreeHash @"4b825dc642cb6eb9a060e54bf8d69288fbee4904"
