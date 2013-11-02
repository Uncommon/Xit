//
//  PBGitLane.m
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//

#import "PBGitLane.h"

int PBGitLane::_s_colorIndex = 0;

int PBGitLane::index() const {
    return _d_index;
}

void PBGitLane::setSha(NSString *sha){
    _d_sha = sha;
    [_d_sha isEqualToString:sha];
}

void PBGitLane::resetColors(){
    _s_colorIndex = 0;
}
