//
//  XTIndexDataSource.m
//  Xit
//
//  Created by German Laullon on 09/08/11.
//

#import "XTUnstagedDataSource.h"
#import "XTRepository.h"
#import "XTFileIndexInfo.h"

@implementation XTUnstagedDataSource

- (id)init {
    self = [super init];
    if (self) {
        items = [NSMutableArray array];
    }

    return self;
}

- (void)setRepo:(XTRepository *)newRepo {
    repo = newRepo;
//    [repo addObserver:self forKeyPath:@"reload" options:NSKeyValueObservingOptionNew context:nil];
//    [repo addObserver:self forKeyPath:@"selectedCommit" options:NSKeyValueObservingOptionNew context:nil];
    [self reload];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
}

- (void)reload {
    [items removeAllObjects];
    if (repo == nil)
        return;

    [repo executeOffMainThread:^{
        NSData *output = [repo executeGitWithArgs:[NSArray arrayWithObjects:@"diff-files", nil] error:nil];
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

        output = [repo executeGitWithArgs:[NSArray arrayWithObjects:@"ls-files", @"--others", @"--exclude-standard", nil] error:nil];
        filesStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        filesStr = [filesStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        files = [filesStr componentsSeparatedByString:@"\n"];
        [files enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
            NSString *file = (NSString *)obj;
            if (file.length > 0) {
                XTFileIndexInfo *fileInfo = [[XTFileIndexInfo alloc] initWithName:file andStatus:@"?"];
                [items addObject:fileInfo];
            }
        }];
    }];
}

- (NSArray *)items {
    return items;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    table = aTableView;
//    [table setDelegate:self];
    return [items count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)rowIndex {
    XTFileIndexInfo *item = [items objectAtIndex:rowIndex];

    return [item valueForKey:column.identifier];
}

@end
