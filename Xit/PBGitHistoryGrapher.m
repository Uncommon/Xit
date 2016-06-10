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

- (instancetype)init
{
  self = [super init];
  if (self) {
    _grapher = [[PBGitGrapher alloc] init];
  }
  return self;
}

- (void)graphCommits:(NSArray *)revList
{
  for (XTHistoryItem *commit in revList) {
    [_grapher decorateCommit:commit];
  }
}

@end
