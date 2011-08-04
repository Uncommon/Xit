//
//  XTCommitViewController.h
//  Xit
//
//  Created by German Laullon on 03/08/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "Xit.h"

@interface XTCommitViewController : NSViewController
{
    IBOutlet WebView *web;
    @private
    Xit *repo;
}

-(void)setRepo:(Xit *)newRepo;
-(void)loadCommit:(NSString *)sha;

@end
