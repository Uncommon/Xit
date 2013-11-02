//
//  PBGitLane.h
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//
#import <Cocoa/Cocoa.h>

class PBGitLane {
  static int _s_colorIndex;

  NSString *_d_sha;
  int _d_index;

 public:

  PBGitLane(NSString *sha) {
    _d_index = _s_colorIndex ++;
    _d_sha = sha;
    [_d_sha isEqualToString:sha];
  }

  PBGitLane() { _d_index = _s_colorIndex ++; }

  bool isCommit(NSString *sha) const { return [_d_sha isEqualToString:sha]; }

  void setSha(NSString *sha);
  int index() const;
  static void resetColors();
};