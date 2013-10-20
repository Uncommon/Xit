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

#import <Cocoa/Cocoa.h>
@interface PBGitHistoryGrapher : NSObject {
  PBGitGrapher *grapher;
}

- (void)graphCommits:(NSArray *)revList;

@end
