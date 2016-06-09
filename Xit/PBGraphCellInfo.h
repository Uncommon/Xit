//
//  PBGraphCellInfo.h
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//

#import <Cocoa/Cocoa.h>
#import <sys/types.h>
#import "PBGitGraphLine.h"

@interface PBGraphCellInfo : NSObject {
  size_t _position;
  struct PBGitGraphLine *_lines;
  int _nLines;
  size_t _numColumns;
}

@property(assign) struct PBGitGraphLine *lines;
@property(assign) int nLines;
@property(assign) size_t position, numColumns;

- (instancetype)initWithPosition:(size_t)p andLines:(struct PBGitGraphLine *)l;

@end