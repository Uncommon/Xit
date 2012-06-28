//
//  XTStagedDataSource.m
//  Xit
//
//  Created by German Laullon on 10/08/11.
//

#import "XTStagedDataSource.h"
#import "XTRepository.h"
#import "XTFileIndexInfo.h"

@implementation XTStagedDataSource

- (void)reload {
    if (repo == nil)
        return;
    [repo executeOffMainThread:^{
        [items removeAllObjects];

        NSData *output = [repo executeGitWithArgs:[NSArray arrayWithObjects:@"diff-index", @"--cached", [repo parentTree], nil] error:nil];
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
