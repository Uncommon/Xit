//
//  XTRepository+Reading.m
//  Xit
//
//  Created by David Catmull on 7/13/12.
//

#import "XTRepository+Reading.h"


@implementation XTRepository (Reading)

- (void)readStashesWithBlock:(void (^)(NSString *, NSString *))block {
    NSData *output = [self executeGitWithArgs:[NSArray arrayWithObjects:@"stash", @"list", @"--pretty=%H %gd %gs", nil] error:nil];

    if (output != nil) {
        NSString *refs = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        NSScanner *scanner = [NSScanner scannerWithString:refs];
        NSString *commit, *name;

        while ([scanner scanUpToString:@" " intoString:&commit]) {
            [scanner scanUpToString:@"\n" intoString:&name];
            block(commit, name);
        }
    }
}

@end
