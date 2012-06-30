//
//  PBGraphCellInfo.m
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//

#import "PBGraphCellInfo.h"

@implementation PBGraphCellInfo

@synthesize lines, position, numColumns, nLines;

- (id)initWithPosition:(size_t)p andLines:(struct PBGitGraphLine *)l {
    position = p;
    lines = l;

    return self;
}

- (void)setLines:(struct PBGitGraphLine *)l {
    free(lines);
    lines = l;
}

- (void)finalize {
    free(lines);
    [super finalize];
}

@end