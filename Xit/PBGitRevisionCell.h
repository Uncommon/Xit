//
//  PBGitRevisionCell.h
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//

#import <Cocoa/Cocoa.h>
#import "PBGitGrapher.h"
#import "PBGraphCellInfo.h"

@interface PBGitRevisionCell : NSTextFieldCell {
  PBGraphCellInfo *cellInfo;
  NSTextFieldCell *textCell;
}

- (NSRect)rectAtIndex:(int)index;

@end
