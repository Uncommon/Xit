//
//  PBGitGrapher.h
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//

#import <Cocoa/Cocoa.h>
#import "XTHistoryItem.h"
#import "PBGitGraphLine.h"
#import "PBGraphCellInfo.h"

#import <Cocoa/Cocoa.h>
@interface PBGitGrapher : NSObject {
  PBGraphCellInfo *previous;
  void *pl;
  int curLane;
}

- (void)decorateCommit:(XTHistoryItem *)commit;
@end
