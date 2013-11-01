//
//  PBGraphCellInfo.m
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//

#import "PBGraphCellInfo.h"

@implementation PBGraphCellInfo

- (id)initWithPosition:(size_t)p andLines:(struct PBGitGraphLine *)l
{
  _position = p;
  _lines = l;

  return self;
}

- (struct PBGitGraphLine *)lines
{
  return _lines;
}

- (void)setLines:(struct PBGitGraphLine *)l
{
  free(_lines);
  _lines = l;
}

- (void)dealloc
{
  free(_lines);
}

@end