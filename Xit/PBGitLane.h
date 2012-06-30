//
//  PBGitLane.h
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//
#import <Cocoa/Cocoa.h>

class PBGitLane {
static int s_colorIndex;

NSString *d_sha;
int d_index;

public:

PBGitLane(NSString *sha){
    d_index = s_colorIndex++;
    d_sha = sha;
    [d_sha isEqualToString:sha];
}

PBGitLane(){
    d_index = s_colorIndex++;
}

bool isCommit(NSString *sha) const {
    return [d_sha isEqualToString:sha];
}

void setSha(NSString *sha);
int index() const;
static void resetColors();
};