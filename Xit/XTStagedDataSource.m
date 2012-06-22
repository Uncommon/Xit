//
//  XTStagedDataSource.m
//  Xit
//
//  Created by German Laullon on 10/08/11.
//

#import "XTStagedDataSource.h"
#import "XTRepository.h"
#import "XTFileIndexInfo.h"

// An empty tree will always have this hash.
#define kEmptyTreeHash @"4b825dc642cb6eb9a060e54bf8d69288fbee4904"

@implementation XTStagedDataSource

- (NSString *)parentTree {
    // If there is no HEAD yet, then use the empty tree for comparing the index
    NSString *parentTree = @"HEAD";

    if ([repo parseReference:parentTree] == nil)
        parentTree = kEmptyTreeHash;
    return parentTree;
}

- (void)reload {
    if (repo == nil)
        return;
    [repo executeOffMainThread:^{
        [items removeAllObjects];

        NSData *output = [repo executeGitWithArgs:[NSArray arrayWithObjects:@"diff-index", @"--cached", [self parentTree], nil] error:nil];
        NSString *filesStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        filesStr = [filesStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSArray *files = [filesStr componentsSeparatedByString:@"\n"];
        [files enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
            NSString *file = (NSString *)obj;
            NSArray *info = [file componentsSeparatedByString:@"\t"];
            if (info.count > 1) {
                NSString *name = [info lastObject];
                NSString *status = [[[info objectAtIndex:0] componentsSeparatedByString:@" "] lastObject];
                status = [status substringToIndex:1];
                XTFileIndexInfo *fileInfo = [[XTFileIndexInfo alloc] initWithName:name andStatus:status];
                [items addObject:fileInfo];
            }
        }];
    }];
}

@end
