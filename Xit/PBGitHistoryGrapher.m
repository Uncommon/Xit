//
//  PBGitHistoryGrapher.m
//  GitX
//
//  Created by Nathan Kinsinger on 2/20/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitHistoryGrapher.h"
#import "PBGitGrapher.h"


@implementation PBGitHistoryGrapher


- (id) init {
    self = [super init];
    if (self) {
        grapher = [[PBGitGrapher alloc] init];
    }
    return self;
}


- (void) graphCommits:(NSArray *)revList {
    for (XTHistoryItem * commit in revList) {
        [grapher decorateCommit:commit];
    }
}


@end
