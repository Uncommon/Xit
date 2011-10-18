//
//  XTRepository+FileVIewCommands.m
//  Xit
//
//  Created by German Laullon on 18/10/11.
//

#import "XTRepository+FileVIewCommands.h"

@implementation XTRepository (FileViewCommands)

- (NSString *)show:(NSString *)file inSha:(NSString *)sha {
    if (!sha) {
        sha = @"HEAD";
    }
    NSString *res = nil;
    NSString *obj = [NSString stringWithFormat:@"%@:%@", sha, file];
    NSData *output = [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"show", obj, nil] error:nil];
    if (output) {
        res = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    }
    return res;
}

@end
