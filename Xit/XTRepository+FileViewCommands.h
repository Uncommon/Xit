//
//  XTRepository+FileVIewCommands.h
//  Xit
//
//  Created by German Laullon on 18/10/11.
//

#import "XTRepository.h"

@interface XTRepository (FileViewCommands)

- (NSString *)show:(NSString *)file inSha:(NSString *)sha;

@end
