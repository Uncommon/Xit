//
//  XTCommitViewController.h
//  Xit
//
//  Created by German Laullon on 03/08/11.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "Xit.h"

@interface XTCommitViewController : NSViewController
{
    IBOutlet WebView * web;
    @private
    Xit * repo;
}

- (void)setRepo:(Xit *)newRepo;
- (NSString *)loadCommit:(NSString *)sha;

@end
