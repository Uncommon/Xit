//
//  XTIndexDataSource.m
//  Xit
//
//  Created by German Laullon on 09/08/11.
//

#import "XTUnstagedDataSource.h"
#import "XTRepository+Parsing.h"
#import "XTFileIndexInfo.h"

@implementation XTUnstagedDataSource

- (void)reload {
    [items removeAllObjects];
    [repo readUnstagedFilesWithBlock:^(NSString *name, NSString *status) {
        [items addObject:[[XTFileIndexInfo alloc] initWithName:name andStatus:status]];
    }];
    [table reloadData];
}

@end
