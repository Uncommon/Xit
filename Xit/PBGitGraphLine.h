//
//  PBLine.h
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//

struct PBGitGraphLine {
  int upper      : 1;
  size_t from    : 8;
  size_t to      : 8;
  int colorIndex : 8;
};
