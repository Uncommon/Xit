//
//  XTRemoteBranchItem.m
//  Xit
//
//  Created by David Catmull on 9/24/11.
//

#import "XTRemoteBranchItem.h"


@implementation XTRemoteBranchItem

@synthesize remote;

- (id)initWithTitle:(NSString *)theTitle remote:(NSString *)remoteName sha:(NSString *)sha {
    if ([super initWithTitle:theTitle andSha:sha] != nil)
        self.remote = remoteName;
    return self;
}

@end
