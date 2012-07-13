//
//  XTRepository.h
//  Xit
//

#import <Foundation/Foundation.h>

@interface XTRepository : NSObject
{
    @private
    NSURL *repoURL;
    NSString *gitCMD;
    NSString *selectedCommit;
    NSString *cachedHeadRef, *cachedHeadSHA;
    NSDictionary *refsIndex;
    FSEventStreamRef stream;
    NSArray *reload;
    dispatch_queue_t queue;
    NSMutableArray *activeTasks;
}

- (id)initWithURL:(NSURL *)url;
- (void)getCommitsWithArgs:(NSArray *)logArgs enumerateCommitsUsingBlock:(void (^)(NSString *))block error:(NSError **)error;
- (NSData *)executeGitWithArgs:(NSArray *)args error:(NSError **)error;
- (NSData *)executeGitWithArgs:(NSArray *)args withStdIn:(NSString *)stdIn error:(NSError **)error;
- (NSString *)parseReference:(NSString *)reference;
- (NSString *)parentTree;
- (NSString *)headRef;
- (NSString *)headSHA;
- (NSString *)shaForRef:(NSString *)ref;

- (void)initializeEventStream;
- (void)start;
- (void)stop;
- (void)waitUntilReloadEnd;

- (void)executeOffMainThread:(void (^)())block;
- (void)addTask:(NSTask *)task;
- (void)removeTask:(NSTask *)task;

@property (assign) NSString *selectedCommit;
@property (assign) NSDictionary *refsIndex;
@property (readonly) dispatch_queue_t queue;
@property (readonly) NSMutableArray *activeTasks;
@property (readonly) NSURL *repoURL;

@end

// An empty tree will always have this hash.
#define kEmptyTreeHash @"4b825dc642cb6eb9a060e54bf8d69288fbee4904"

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[]);
