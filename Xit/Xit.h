//
//  Xit.h
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import <Cocoa/Cocoa.h>

@class XTSideBarDataSource;

@interface Xit : NSDocument {
    IBOutlet XTSideBarDataSource *sideBarDS;
@private
    FSEventStreamRef stream;
    NSURL *repoURL;
    NSString *gitCMD;
    BOOL autoReload;
    NSArray* reload;
}

-(NSData *)exectuteGitWithArgs:(NSArray *)args error:(NSError **)error;
-(void)initializeEventStream;
-(BOOL)isAutoReload;
-(void)setAutoReload:(BOOL)reload;
-(void)start;
-(void)stop;
-(NSURL *)repoURL;

@end

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[]);