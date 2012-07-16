//
//  XTRepository+Reading.h
//  Xit
//
//  Created by David Catmull on 7/13/12.
//

#import "XTRepository.h"


@interface XTRepository (Reading)

- (void)readStashesWithBlock:(void (^)(NSString *commit, NSString *name))block;

@end
