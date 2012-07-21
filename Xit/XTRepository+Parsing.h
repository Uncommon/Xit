//
//  XTRepository+Parsing.h
//  Xit
//
//  Created by David Catmull on 7/13/12.
//

#import "XTRepository.h"


@interface XTRepository (Reading)

- (BOOL)readRefsWithLocalBlock:(void (^)(NSString *name, NSString *commit))localBlock
                   remoteBlock:(void (^)(NSString *remoteName, NSString *branchName, NSString *commit))remoteBlock
                      tagBlock:(void (^)(NSString *name, NSString *commit))tagBlock;
- (BOOL)readStagedFilesWithBlock:(void (^)(NSString *name, NSString *status))block;
- (BOOL)readUnstagedFilesWithBlock:(void (^)(NSString *name, NSString *status))block;
- (BOOL)readStashesWithBlock:(void (^)(NSString *commit, NSString *name))block;

- (NSArray *)fileNamesForRef:(NSString *)ref;

@end
