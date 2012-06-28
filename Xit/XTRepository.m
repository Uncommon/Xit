//
//  XTRepository.m
//  Xit
//
//  Created by VMware Inc. on 8/23/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import "XTRepository.h"

// An empty tree will always have this hash.
#define kEmptyTreeHash @"4b825dc642cb6eb9a060e54bf8d69288fbee4904"

@implementation XTRepository

@synthesize selectedCommit;
@synthesize refsIndex;
@synthesize queue;
@synthesize activeTasks;
@synthesize repoURL;

+ (NSString *)gitPath {
    NSArray *paths = [NSArray arrayWithObjects:
                      @"/usr/bin/git",
                      @"/usr/local/git/bin/git",
                      nil];

    for (NSString *path in paths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            return path;
    }
    return nil;
}


- (id)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        gitCMD = [XTRepository gitPath];
        repoURL = url;
        NSMutableString *qName = [NSMutableString stringWithString:@"com.xit.queue."];
        [qName appendString:[url path]];
        queue = dispatch_queue_create([qName cStringUsingEncoding:NSASCIIStringEncoding], NULL);
        activeTasks = [NSMutableArray array];
    }

    return self;
}

- (void)executeOffMainThread:(void (^)())block {
    if ([NSThread isMainThread])
        dispatch_async(queue, block);
    else
        block();
}

- (void)addTask:(NSTask *)task {
    [self willChangeValueForKey:@"activeTasks"];
    [activeTasks addObject:task];
    [self didChangeValueForKey:@"activeTasks"];
}

- (void)removeTask:(NSTask *)task {
    [self willChangeValueForKey:@"activeTasks"];
    [activeTasks removeObject:task];
    [self didChangeValueForKey:@"activeTasks"];
}

- (void)waitUntilReloadEnd {
    dispatch_sync(queue, ^{ });
}

- (void)getCommitsWithArgs:(NSArray *)logArgs enumerateCommitsUsingBlock:(void (^) (NSString *)) block error:(NSError **)error {
    if (repoURL == nil) {
        if (error != NULL)
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:fnfErr userInfo:nil];
        return;
    }
    if (![self parseReference:@"HEAD"])
        return;  // There are no commits.

    NSMutableArray *args = [NSMutableArray arrayWithArray:logArgs];

    [args insertObject:@"log" atIndex:0];
    [args insertObject:@"-z" atIndex:1];
    NSData *zero = [NSData dataWithBytes:"" length:1];

    NSLog (@"****command = git %@", [args componentsJoinedByString:@" "]);
    NSTask *task = [[NSTask alloc] init];
    [self addTask:task];
    [task setCurrentDirectoryPath:[repoURL path]];
    [task setLaunchPath:gitCMD];
    [task setArguments:args];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];

    [task  launch];
    NSMutableData *output = [NSMutableData data];

    BOOL end = NO;
    while (!end) {
        NSData *availableData = [[pipe fileHandleForReading] availableData];
        [output appendData:availableData];

        end = (([availableData length] == 0) && ![task isRunning]);
        if (end)
            [output appendData:zero];

        NSRange searchRange = NSMakeRange (0, [output length]);
        NSRange zeroRange = [output rangeOfData:zero options:0 range:searchRange];
        while (zeroRange.location != NSNotFound) {
            NSRange commitRange = NSMakeRange (searchRange.location, (zeroRange.location - searchRange.location));
            NSData *commit = [output subdataWithRange:commitRange];
            NSString *str = [[NSString alloc] initWithData:commit encoding:NSUTF8StringEncoding];
            if (str != nil)
                block (str);
            searchRange = NSMakeRange (zeroRange.location + 1, [output length] - (zeroRange.location + 1));
            zeroRange = [output rangeOfData:zero options:0 range:searchRange];
        }
        output = [NSMutableData dataWithData:[output subdataWithRange:searchRange]];
    }

    int status = [task terminationStatus];
    NSLog (@"**** status = %d", status);

    if (status != 0) {
        NSString *string = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"git"
                                         code:status
                                     userInfo:[NSDictionary dictionaryWithObject:string forKey:@"output"]];
        }
    }
    [self removeTask:task];
}

- (NSData *)executeGitWithArgs:(NSArray *)args error:(NSError **)error {
    return [self executeGitWithArgs:args withStdIn:nil error:error];
}

- (NSData *)executeGitWithArgs:(NSArray *)args withStdIn:(NSString *)stdIn error:(NSError **)error {
    if (repoURL == nil)
        return nil;
    NSLog(@"****command = git %@", [args componentsJoinedByString:@" "]);
    NSTask *task = [[NSTask alloc] init];
    [self addTask:task];
    [task setCurrentDirectoryPath:[repoURL path]];
    [task setLaunchPath:gitCMD];
    [task setArguments:args];

    if (stdIn != nil) {
#if 0
        NSLog(@"**** stdin = %lu", stdIn.length);
#else
        NSLog(@"**** stdin = %lu\n%@", stdIn.length, stdIn);
#endif
        NSPipe *stdInPipe = [NSPipe pipe];
        [[stdInPipe fileHandleForWriting] writeData:[stdIn dataUsingEncoding:NSUTF8StringEncoding]];
        [[stdInPipe fileHandleForWriting] closeFile];
        [task setStandardInput:stdInPipe];
    }

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];

    NSLog(@"task.currentDirectoryPath=%@", task.currentDirectoryPath);
    [task  launch];
    NSData *output = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];

    int status = [task terminationStatus];
    NSLog(@"**** status = %d", status);

    if (status != 0) {
        NSString *string = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        NSLog(@"**** output = %@", string);
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"git"
                                         code:status
                                     userInfo:[NSDictionary dictionaryWithObject:string forKey:@"output"]];
        }
        output = nil;
    }
    [self removeTask:task];
    return output;
}

- (NSString *)parseReference:(NSString *)reference {
    NSError *error = nil;
    NSArray *args = [NSArray arrayWithObjects:@"rev-parse", @"--verify", reference, nil];
    NSData *output = [self executeGitWithArgs:args error:&error];

    if (output == nil)
        return nil;
    return [[[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding] autorelease];
}

// Returns kEmptyTreeHash if the repository is empty, otherwise "HEAD"
- (NSString *)parentTree {
    NSString *parentTree = @"HEAD";

    if ([self parseReference:parentTree] == nil)
        parentTree = kEmptyTreeHash;
    return parentTree;
}

// XXX tmp
- (void)start {
    [self initializeEventStream];
}

- (void)stop {
    FSEventStreamStop(stream);
    FSEventStreamInvalidate(stream);
}

#pragma mark - monitor file system
- (void)initializeEventStream {
    if (repoURL == nil)
        return;
    NSString *myPath = [[repoURL URLByAppendingPathComponent:@".git"] path];
    NSArray *pathsToWatch = [NSArray arrayWithObject:myPath];
    void *appPointer = (void *)self;
    FSEventStreamContext context = { 0, appPointer, NULL, NULL, NULL };
    NSTimeInterval latency = 3.0;

    stream = FSEventStreamCreate(NULL,
                                 &fsevents_callback,
                                 &context,
                                 (CFArrayRef)pathsToWatch,
                                 kFSEventStreamEventIdSinceNow,
                                 (CFAbsoluteTime)latency,
                                 kFSEventStreamCreateFlagUseCFTypes
                                 );

    FSEventStreamScheduleWithRunLoop(stream,
                                     CFRunLoopGetCurrent(),
                                     kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
}

int event = 0;

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[]){
    XTRepository *repo = (XTRepository *)userData;

    event++;

    NSMutableArray *reload = [NSMutableArray arrayWithCapacity:numEvents];
    for (size_t i = 0; i < numEvents; i++) {
        NSString *path = [(NSArray *) eventPaths objectAtIndex:i];
        NSRange r = [path rangeOfString:@".git" options:NSBackwardsSearch];
        path = [path substringFromIndex:r.location];
        [reload addObject:path];
        NSLog(@"%d\t%@", event, path);
    }

    [repo setValue:reload forKey:@"reload"];
}

@end
