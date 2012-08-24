//
//  XTStagedDataSource.m
//  Xit
//
//  Created by David Catmull on 6/22/11.
//

#import "XTStagingDataSourceBase.h"
#import "XTRepository.h"
#import "XTFileIndexInfo.h"

@implementation XTStagingDataSourceBase

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
    // For subclasses.
}

- (NSArray *)items {
    return items;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    table = aTableView;
    return [items count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)rowIndex {
    if (rowIndex >= [items count])
        return nil;

    XTFileIndexInfo *item = [items objectAtIndex:rowIndex];

    return [item valueForKey:column.identifier];
}

@end