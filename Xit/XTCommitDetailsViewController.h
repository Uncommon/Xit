//
//  XTCommitDetailsViewController.h
//  Xit
//
//  Created by German Laullon Padilla on 13/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface XTCommitDetailsViewController : NSViewController {
    NSTextField *sha;
    NSTextField *subject;
}

@property (assign) IBOutlet NSTextField *sha;
@property (assign) IBOutlet NSTextField *subject;

@end
