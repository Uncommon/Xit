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
    if (repo == nil)
        return;
    dispatch_async(repo.queue, ^{

                       [items removeAllObjects];

                       NSData *output = [repo exectuteGitWithArgs:[NSArray arrayWithObjects:@"diff-index", @"--cached", @"HEAD", nil] error:nil];
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
                   });
}

// just for tests
- (NSArray *)items {
    return items;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    table = aTableView;
    //    [table setDelegate:self];
    return [items count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    XTFileIndexInfo *item = [items objectAtIndex:rowIndex];

    return [item valueForKey:aTableColumn.identifier];
}

@end
