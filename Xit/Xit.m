//
//  Xit.m
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import "Xit.h"
#import "XTSideBarDataSource.h"

@implementation Xit

- (id)init
{
    self = [super init];
    if (self) {
        NSLog(@"[init]");
        repoURL=[NSURL URLWithString:@"/Users/laullon/xcode/gitx"]; // Default only for test.
        gitCMD=@"/usr/bin/git";  // XXXX
    }
    return self;
}

- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    absoluteURL=[absoluteURL URLByDeletingPathExtension];
    self = [super initWithContentsOfURL:absoluteURL ofType:typeName error:outError];
    if (self) {
        repoURL=absoluteURL;
        gitCMD=@"/usr/bin/git";  // XXXX
    }
    return self;
}

-(NSURL *)repoURL
{
    return repoURL;
}

// XXX tmp
-(void)start
{
    [self initializeEventStream];
}

-(void)stop
{
    FSEventStreamStop(stream);
    FSEventStreamInvalidate(stream);
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"Xit";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    [sideBarDS setRepo:self];
    [historyDS setRepo:self];
    [self start];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    /*
     Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
     You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
     */
    if (outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
    }
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    /*
     Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
     You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
     */
    if (outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
    }
    return YES;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    return true; // XXX
}

#pragma mark - git commands

-(NSData *)exectuteGitWithArgs:(NSArray *)args error:(NSError **)error
{
    NSLog(@"****command = git %@",[args componentsJoinedByString:@" "]);
    NSTask* task = [[NSTask alloc] init];
    [task setCurrentDirectoryPath:[repoURL path]];
	[task setLaunchPath:gitCMD];
	[task setArguments:args];
    
	NSPipe* pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
    
    [task  launch];
    NSMutableData *output=[NSMutableData data];
    int timeOut=0;
    while ([task isRunning] && (++timeOut<=50))
    {
        NSLog(@"Polling... (%d)",timeOut);
        [output appendData:[[pipe fileHandleForReading] readDataToEndOfFile]];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
    }

    int status = [task terminationStatus];
    
    
    // Only for debug
    NSString *string = [[NSString alloc] initWithData: output encoding: NSUTF8StringEncoding];
    NSLog(@"**** status = %d",status);
//    NSLog(@"**** output = %@",string);
    
    if (status != 0){
        if (error != NULL) {
            *error=[NSError errorWithDomain:@"git" 
                                       code:status 
                                   userInfo:[NSDictionary dictionaryWithObject:string forKey:@"output"]];
        }
        output=nil;
    }
    
    return output;
}

#pragma mark - monitor file system
-(void)initializeEventStream
{
    NSString *myPath = [[repoURL URLByAppendingPathComponent:@".git"] absoluteString];
    NSArray *pathsToWatch = [NSArray arrayWithObject:myPath];
    void *appPointer = (void *)self;
    FSEventStreamContext context = {0, appPointer, NULL, NULL, NULL};
    NSTimeInterval latency = 3.0;
    stream = FSEventStreamCreate(NULL,
                                 &fsevents_callback,
                                 &context,
                                 (CFArrayRef) pathsToWatch,
	                             kFSEventStreamEventIdSinceNow,
                                 (CFAbsoluteTime) latency,
                                 kFSEventStreamCreateFlagUseCFTypes
                                 );
    
    FSEventStreamScheduleWithRunLoop(stream,
                                     CFRunLoopGetCurrent(),
                                     kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
}

int event=0;

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[])
{
    Xit *xit = (Xit *)userData;
    event++;
    
    NSMutableArray *reload=[NSMutableArray arrayWithCapacity:numEvents];
    for(size_t i=0; i < numEvents; i++){
        NSString *path=[(NSArray *)eventPaths objectAtIndex:i];
        NSRange r=[path rangeOfString:@".git" options:NSBackwardsSearch];
        path=[path substringFromIndex:r.location];
        [reload addObject:path];
        NSLog(@"%d\t%@",event,path);
    }
    
    [xit setValue:reload forKey:@"reload"];
}

#pragma mark - temp
-(IBAction)reload:(id)sender
{
    NSLog(@"########## reload ##########");
    [self setValue:[NSArray arrayWithObjects:@".git/refs/",@".git/logs/",nil] forKey:@"reload"];
}
@end
