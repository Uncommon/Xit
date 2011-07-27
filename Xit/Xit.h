//
//  Xit.h
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import <Cocoa/Cocoa.h>

@class XTSideBarDataSource;
@class XTHistoryDataSource;

@interface Xit : NSDocument {
    IBOutlet XTSideBarDataSource *sideBarDS;
    IBOutlet XTHistoryDataSource *historyDS;
@private
    FSEventStreamRef stream;
    NSURL *repoURL;
    NSString *gitCMD;
    NSArray* reload;
}

-(NSData *)exectuteGitWithArgs:(NSArray *)args error:(NSError **)error;
-(void)initializeEventStream;
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