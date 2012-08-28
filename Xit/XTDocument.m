//
//  Xit.m
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import "XTDocument.h"
#import "XTDocController.h"
#import "XTRepository.h"
#import "XTStatusView.h"

@implementation XTDocument

@synthesize repository = repo;

- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    self = [super initWithContentsOfURL:absoluteURL ofType:typeName error:outError];
    if (self) {
        repoURL = absoluteURL;
        repo = [[XTRepository alloc] initWithURL:repoURL];
    }
    return self;
}

- (id)initForURL:(NSURL *)absoluteDocumentURL withContentsOfURL:(NSURL *)absoluteDocumentContentsURL ofType:(NSString *)typeName error:(NSError **)outError {
    return [self initWithContentsOfURL:absoluteDocumentURL ofType:typeName error:outError];
}

- (void)makeWindowControllers {
    XTDocController *controller = [[XTDocController alloc] initWithDocument:self];

    [self addWindowController:controller];
    [repo start];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    NSURL *gitURL = [absoluteURL URLByAppendingPathComponent:@".git"];

    if ([[NSFileManager defaultManager] fileExistsAtPath:[gitURL path]])
        return YES;

    if (outError != NULL) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"The folder does not contain a Git repository." forKey:NSLocalizedFailureReasonErrorKey];
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:userInfo];
    }
    return NO;
}

- (void)updateChangeCount:(NSDocumentChangeType)change {
    // Do nothing. There is no need for an "unsaved" state.
}

#pragma mark - temp
- (IBAction)reload:(id)sender {
    NSLog(@"########## reload ##########");
    [repo reloadPaths:[NSArray arrayWithObjects:@".git/refs/", @".git/logs/", nil]];
}
@end
