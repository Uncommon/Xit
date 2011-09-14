//
//  XTFileListDataSource.m
//  Xit
//
//  Created by German Laullon on 13/09/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "XTFileListDataSource.h"
#import "XTRepository.h"

@interface XTFileListDataSource ()
- (void)_reload;
@end

@implementation XTFileListDataSource

- (id)init {
    self = [super init];
    if (self) {
        roots = [NSMutableArray array];
    }

    return self;
}

- (void)setRepo:(XTRepository *)newRepo {
    repo = newRepo;
    [self reload];
}

- (void)reload {
    dispatch_async(repo.queue, ^{ [self _reload]; });
}

- (void)_reload {
    NSMutableDictionary *nodes = [NSMutableDictionary dictionary];
    NSData *output = [repo exectuteGitWithArgs:[NSArray arrayWithObjects:@"ls-tree", @"--name-only", @"-r", repo.selectedCommit, nil] error:nil];

    if (output) {
        NSString *ls = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        ls = [ls stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSArray *files = [ls componentsSeparatedByString:@"\n"];
        for (NSString *file in files) {
            NSString *path = [file stringByDeletingLastPathComponent];
            NSLog(@"path: '%@' file: '%@'", path, file);
//            NSString *fileName=[file lastPathComponent];
            NSTreeNode *parentNode = [nodes objectForKey:path];
            if (!parentNode || path.length == 0) {
                parentNode = [NSTreeNode treeNodeWithRepresentedObject:file];
                [roots addObject:parentNode];
                [nodes setObject:parentNode forKey:path];
            } else {
                [[parentNode mutableChildNodes] addObject:[NSTreeNode treeNodeWithRepresentedObject:path]];
            }
        }
    }
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    NSInteger res = 0;

    if (item == nil) {
        res = [roots count];
    } else if ([item isKindOfClass:[NSTreeNode class]]) {
        NSTreeNode *node = (NSTreeNode *)item;
        res = [[node childNodes] count];
    }
    return res;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    NSTreeNode *node = (NSTreeNode *)item;
    BOOL res = [[node childNodes] count] > 0;

    return res;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    NSTreeNode *node = (NSTreeNode *)item;

    return [[node childNodes] objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSTreeNode *node = (NSTreeNode *)item;

    return [node representedObject];
}

@end
