//
//  Xit.h
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import <Cocoa/Cocoa.h>

@class XTSideBarDataSource;
@class XTHistoryDataSource;
@class XTCommitViewController;

@interface Xit : NSDocument {
    IBOutlet XTSideBarDataSource *sideBarDS;
    IBOutlet XTHistoryDataSource *historyDS;
    IBOutlet XTCommitViewController *commitViewController;
    IBOutlet NSView *commitView;
@private
    FSEventStreamRef stream;
    NSURL *repoURL;
    NSString *gitCMD;
    NSArray* reload;
    NSString *selectedCommit;
}

@property(assign) NSString *selectedCommit;

-(void)getCommitsWithArgs:(NSArray *)logArgs enumerateCommitsUsingBlock:(void(^)(NSString*))block error:(NSError **)error;
-(NSData *)exectuteGitWithArgs:(NSArray *)args error:(NSError **)error;
-(void)initializeEventStream;
-(void)start;
-(void)stop;
-(NSURL *)repoURL;

// XXX TEMP
-(IBAction)reload:(id)sender;

@end

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[]);