//
//  XTRepository.h
//  Xit
//
//  Created by VMware Inc. on 8/23/11.
//

#import <Foundation/Foundation.h>

@interface XTRepository : NSObject
{
    @private
    NSURL *repoURL;
    NSString *gitCMD;
    NSString *selectedCommit;
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
- (NSString *)parseReference:(NSString*)reference;

- (void)initializeEventStream;
- (void)start;
- (void)stop;
- (void)waitUntilReloadEnd;

- (void)addTask:(NSTask *)task;
- (void)removeTask:(NSTask *)task;

@property (assign) NSString *selectedCommit;
@property (assign) NSDictionary *refsIndex;
@property (readonly) dispatch_queue_t queue;
@property (readonly) NSMutableArray *activeTasks;
@property (readonly) NSURL *repoURL;

@end

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[]);