//
//  PBGitHistoryGrapher.h
//  GitX
//
//  Created by Nathan Kinsinger on 2/20/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kCurrentQueueKey @"kCurrentQueueKey"
#define kNewCommitsKey @"kNewCommitsKey"

@class PBGitGrapher;

@interface PBGitHistoryGrapher : NSObject {
  PBGitGrapher *_grapher;
}

- (void)graphCommits:(NSArray *)revList;

@end
