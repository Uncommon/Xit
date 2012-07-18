//
//  XTRepository+Parsing.h
//  Xit
//
//  Created by David Catmull on 7/13/12.
//

#import "XTRepository.h"


@interface XTRepository (Reading)

- (void)readRefsWithLocalBlock:(void (^)(NSString *name, NSString *commit))localBlock
                   remoteBlock:(void (^)(NSString *remoteName, NSString *branchName, NSString *commit))remoteBlock
                      tagBlock:(void (^)(NSString *name, NSString *commit))tagBlock;
- (void)readStashesWithBlock:(void (^)(NSString *commit, NSString *name))block;

@end
