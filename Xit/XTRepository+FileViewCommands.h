//
//  XTRepository+FileVIewCommands.h
//  Xit
//
//  Created by German Laullon on 18/10/11.
//

#import "XTRepository.h"

@interface XTRepository (FileViewCommands)

- (NSString *)show:(NSString *)file inSha:(NSString *)sha;
- (NSString *)blame:(NSString *)file inSha:(NSString *)sha;
- (NSString *)diffToHead:(NSString *)file fromSha:(NSString *)sha;
- (NSString *)diff:(NSString *)file fromSha:(NSString *)sha;

@end
