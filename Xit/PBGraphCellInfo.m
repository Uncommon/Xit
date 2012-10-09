//
//  PBGraphCellInfo.m
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//

#import "PBGraphCellInfo.h"

@implementation PBGraphCellInfo

@synthesize position, numColumns, nLines;

- (id)initWithPosition:(size_t)p andLines:(struct PBGitGraphLine *)l {
    position = p;
    lines = l;

    return self;
}

- (struct PBGitGraphLine *)lines {
    return lines;
}

- (void)setLines:(struct PBGitGraphLine *)l {
    free(lines);
    lines = l;
}

- (void)dealloc {
    free(lines);
}

@end