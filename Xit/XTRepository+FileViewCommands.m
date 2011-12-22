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

- (NSString *)blame:(NSString *)file inSha:(NSString *)sha {
    if (!sha) {
        sha = @"HEAD";
    }
    NSString *res = nil;
    NSData *output = [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"blame", @"-p", file, sha, nil] error:nil];
    if (output) {
        res = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    }
    return res;
}

- (NSString *)diffToHead:(NSString *)file fromSha:(NSString *)sha {
    sha = [NSString stringWithFormat:@"%@..HEAD", sha];
    return [self diff:file fromSha:sha];
}

- (NSString *)diff:(NSString *)file fromSha:(NSString *)sha {
    NSString *res = nil;
    NSData *output = [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"diff", sha, @"--", file, nil] error:nil];
    if (output) {
        res = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    }
    return res;
}

@end
