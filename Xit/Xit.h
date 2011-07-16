//
//  Xit.h
//  Xit
//
//  Created by glaullon on 7/15/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Xit : NSDocument {
@private
    NSURL *repoURL;
    NSString *gitCMD;
}

-(NSTask *)createTaskWithArgs:(NSArray *)args;

@end
