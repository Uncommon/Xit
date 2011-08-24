//
//  XTRepository.h
//  Xit
//
//  Created by VMware Inc. on 8/23/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
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
}

- (void)getCommitsWithArgs:(NSArray *)logArgs enumerateCommitsUsingBlock:(void(^) (NSString *)) block error:(NSError **)error;
- (NSData *)exectuteGitWithArgs:(NSArray *)args error:(NSError **)error;
- (NSData *)exectuteGitWithArgs:(NSArray *)args withStdIn:(NSString *)stdIn error:(NSError **)error;

- (void)initializeEventStream;
- (void)start;
- (void)stop;

@property (assign) NSString *selectedCommit;
@property (assign) NSDictionary *refsIndex;

@end

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[]);