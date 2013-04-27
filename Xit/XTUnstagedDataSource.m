#import "XTUnstagedDataSource.h"
#import "XTFileIndexInfo.h"
#import "XTModDateTracker.h"
#import "XTRepository+Parsing.h"

@implementation XTUnstagedDataSource

- (BOOL)shouldReloadForPaths:(NSArray *)paths {
    if ([indexTracker hasDateChanged])
        return YES;
    for (NSString *path in paths)
        if (![path hasPrefix:@".git/"])
            return YES;
    return NO;
}

- (void)reload {
    [items removeAllObjects];
    [repo readUnstagedFilesWithBlock:^(NSString *name, NSString *status) {
        [items addObject:[[XTFileIndexInfo alloc] initWithName:name andStatus:status]];
    }];
    [table reloadData];
}

@end
