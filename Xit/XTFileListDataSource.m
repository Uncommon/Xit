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
- (NSTreeNode *)findTreeNodeForPath:(NSString *)path;
@end

@implementation XTFileListDataSource

- (id)init {
    self = [super init];
    if (self) {
        root = [NSTreeNode treeNodeWithRepresentedObject:@"root"];
        nodes = [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)setRepo:(XTRepository *)newRepo {
    repo = newRepo;
    [repo addObserver:self forKeyPath:@"selectedCommit" options:NSKeyValueObservingOptionNew context:nil];
    [self reload];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"selectedCommit"]) {
        [self reload];
    }
}

- (void)reload {
    dispatch_async(repo.queue, ^{ [self _reload]; });
}

- (void)_reload {
    [nodes removeAllObjects];
    [[root mutableChildNodes] removeAllObjects];

    NSString *sha = repo.selectedCommit;
    if (!sha)
        sha = @"HEAD";

    NSData *output = [repo exectuteGitWithArgs:[NSArray arrayWithObjects:@"ls-tree", @"--name-only", @"-r", sha, nil] error:nil];

    if (output) {
        NSString *ls = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        ls = [ls stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSArray *files = [ls componentsSeparatedByString:@"\n"];
        for (NSString *file in files) {
            NSString *path = [file stringByDeletingLastPathComponent];
//            NSString *fileName = [file lastPathComponent];
//            NSLog(@"path: '%@' file: '%@'", path, file);
            NSTreeNode *node = [NSTreeNode treeNodeWithRepresentedObject:file];
            if (path.length == 0) {
                [[root mutableChildNodes] addObject:node];
            } else {
                NSTreeNode *parentNode = [self findTreeNodeForPath:path];
                [[parentNode mutableChildNodes] addObject:node];
            }
        }
    }
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"lastPathComponent"
                                                                   ascending:YES
                                                                    selector:@selector(localizedCaseInsensitiveCompare:)];
    [root sortWithSortDescriptors:[NSArray arrayWithObject:sortDescriptor] recursively:YES];

    [table reloadData];
}

- (NSTreeNode *)findTreeNodeForPath:(NSString *)path {
    NSTreeNode *pathNode = [nodes objectForKey:path];

    if (!pathNode) {
        pathNode = [NSTreeNode treeNodeWithRepresentedObject:path];
        NSString *parentPath = [path stringByDeletingLastPathComponent];
        if (parentPath.length == 0) {
            [[root mutableChildNodes] addObject:pathNode];
        } else {
            NSTreeNode *parentNode = [self findTreeNodeForPath:parentPath];
            [[parentNode mutableChildNodes] addObject:pathNode];
        }
        [nodes setObject:pathNode forKey:path];
    }
    return pathNode;
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    table = outlineView;

    NSInteger res = 0;

    if (item == nil) {
        res = [root.childNodes count];
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
    id res;

    if (item == nil) {
        res = [root.childNodes objectAtIndex:index];
    } else {
        NSTreeNode *node = (NSTreeNode *)item;
        res = [[node childNodes] objectAtIndex:index];
    }
    return res;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSTreeNode *node = (NSTreeNode *)item;

    return [node representedObject];
}

@end
