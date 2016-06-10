#import "XTDocument.h"
#import "XTRepository.h"
#import "Xit-Swift.h"
#include "XTQueueUtils.h"

@implementation XTDocument

@synthesize repository = _repo;

- (instancetype)initWithContentsOfURL:(NSURL *)absoluteURL
                     ofType:(NSString *)typeName
                      error:(NSError **)outError
{
  self =
      [super initWithContentsOfURL:absoluteURL ofType:typeName error:outError];
  if (self) {
    _repoURL = absoluteURL;
    _repo = [[XTRepository alloc] initWithURL:_repoURL];
  }
  return self;
}

- (instancetype)initForURL:(NSURL *)absoluteDocumentURL
    withContentsOfURL:(NSURL *)absoluteDocumentContentsURL
               ofType:(NSString *)typeName
                error:(NSError **)outError
{
  return [self initWithContentsOfURL:absoluteDocumentURL
                              ofType:typeName
                               error:outError];
}

- (void)makeWindowControllers
{
  XTWindowController *controller =
      [[XTWindowController alloc] initWithWindowNibName:@"XTDocument"];

  [self addWindowController:controller];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL
             ofType:(NSString *)typeName
              error:(NSError **)outError
{
  NSURL *gitURL = [absoluteURL URLByAppendingPathComponent:@".git"];

  if ([[NSFileManager defaultManager] fileExistsAtPath:gitURL.path])
    return YES;

  if (outError != NULL) {
    NSDictionary *userInfo =
        @{NSLocalizedFailureReasonErrorKey :
          @"The folder does not contain a Git repository."};
    *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                    code:NSFileReadUnknownError
                                userInfo:userInfo];
  }
  return NO;
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo
{
  [_repo shutDown];
  WaitForQueue(_repo.queue);
  [super canCloseDocumentWithDelegate:delegate
                  shouldCloseSelector:shouldCloseSelector
                          contextInfo:contextInfo];
}

- (void)updateChangeCount:(NSDocumentChangeType)change
{
  // Do nothing. There is no need for an "unsaved" state.
}

@end
