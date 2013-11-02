#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "XTRepository.h"

/**
  The commit view displays the info and content for a selected commit.
 */
@interface XTCommitViewController : NSViewController {
  IBOutlet WebView *_web;
 @private
  XTRepository *_repo;
}

- (void)setRepo:(XTRepository *)newRepo;
- (NSString *)loadCommit:(NSString *)sha;

@end
