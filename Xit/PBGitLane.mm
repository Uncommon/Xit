//
//  PBGitLane.m
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//

#import "PBGitLane.h"

int PBGitLane::s_colorIndex = 0;

int PBGitLane::index() const {
    return d_index;
}

void PBGitLane::setSha(NSString *sha){
    d_sha = sha;
    [d_sha isEqualToString:sha];
}

void PBGitLane::resetColors(){
    s_colorIndex = 0;
}
