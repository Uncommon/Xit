//
//  PBGraphCellInfo.h
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//

#import <Cocoa/Cocoa.h>
#import <sys/types.h>
#import "PBGitGraphLine.h"

#import <Cocoa/Cocoa.h>
@interface PBGraphCellInfo : NSObject {
  size_t position;
  struct PBGitGraphLine *lines;
  int nLines;
  size_t numColumns;
}

@property(assign) struct PBGitGraphLine *lines;
@property(assign) int nLines;
@property(assign) size_t position, numColumns;

- (id)initWithPosition:(size_t)p andLines:(struct PBGitGraphLine *)l;

@end