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

@interface PBGitGrapher : NSObject {
  PBGraphCellInfo *_previous;
  void *_pl;
  int _curLane;
}

- (void)decorateCommit:(XTHistoryItem *)commit;
@end
