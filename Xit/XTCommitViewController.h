//
//  XTCommitViewController.h
//  Xit
//
//  Created by German Laullon on 03/08/11.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "XTRepository.h"

// The commit view displays the info and content for a selected commit.
@interface XTCommitViewController : NSViewController
{
    IBOutlet WebView *web;
    @private
    XTRepository *repo;
}

- (void)setRepo:(XTRepository *)newRepo;
- (NSString *)loadCommit:(NSString *)sha;

@end
