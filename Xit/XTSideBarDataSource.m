//
//  XTSideBarDataSource.m
//  Xit
//
//  Created by German Laullon on 17/07/11.
//

#import "XTSideBarDataSource.h"
#import "XTSideBarItem.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "XTRemoteBranchItem.h"
#import "XTTagItem.h"
#import "XTRemotesItem.h"
#import "XTSideBarTableCellView.h"
#import "NSMutableDictionary+MultiObjectForKey.h"

@interface XTSideBarDataSource ()
- (void)_reload;
@end

@implementation XTSideBarDataSource

@synthesize roots;

- (id)init {
    self = [super init];
    if (self) {
        XTSideBarItem *branches = [[XTSideBarItem alloc] initWithTitle:@"BRANCHES"];
        XTSideBarItem *tags = [[XTSideBarItem alloc] initWithTitle:@"TAGS"];
        XTRemotesItem *remotes = [[XTRemotesItem alloc] initWithTitle:@"REMOTES"];
        XTSideBarItem *stashes = [[XTSideBarItem alloc] initWithTitle:@"STASHES"];
        roots = [NSArray arrayWithObjects:branches, tags, remotes, stashes, nil];
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setRepo:(XTRepository *)newRepo {
    repo = newRepo;
    if (repo != nil) {
        [repo addReloadObserver:self selector:@selector(repoChanged:)];
        [self reload];
    }
}

- (void)repoChanged:(NSNotification *)note {
    NSArray *paths = [[note userInfo] objectForKey:XTPathsKey];

    for (NSString *path in paths) {
        if ([path hasPrefix:@".git/refs/"]) {
            [self reload];
            break;
        }
    }
    [outline performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

- (void)reload {
    dispatch_async(repo.queue, ^{
        [self _reload];
        if (!self->didInitialExpandGroups) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [outline expandItem:nil expandChildren:YES];
            });
            self->didInitialExpandGroups = YES;
        }
    });
}

- (void)_reload {
    [self willChangeValueForKey:@"reload"];
    NSMutableDictionary *refsIndex = [NSMutableDictionary dictionary];
    [self reloadBranches:refsIndex];
    [self reloadStashes:refsIndex];
    // TODO: Consolidate refsIndex reading and storage into one class.
    repo.refsIndex = refsIndex;
    [outline performSelectorOnMainThread:@selector(reloadData)
                              withObject:nil
                           waitUntilDone:YES];
    currentBranch = [repo currentBranch];
    [self didChangeValueForKey:@"reload"];
    [outline performSelectorOnMainThread:@selector(reloadData)
                              withObject:nil
                           waitUntilDone:YES];
}

- (void)reloadStashes:(NSMutableDictionary *)refsIndex {
    XTSideBarItem *stashes = [roots objectAtIndex:XT_STASHES];

    [stashes clean];
    [repo readStashesWithBlock:^(NSString *commit, NSString *name) {
        XTSideBarItem *stash = [[XTStashItem alloc] initWithTitle:name];
        [stashes addchild:stash];
        [refsIndex addObject:stash forKey:commit];
    }];
}

- (void)reloadBranches:(NSMutableDictionary *)refsIndex {
    XTSideBarItem *branches = [roots objectAtIndex:XT_BRANCHES];
    XTSideBarItem *tags = [roots objectAtIndex:XT_TAGS];
    XTRemotesItem *remotes = [roots objectAtIndex:XT_REMOTES];

    NSMutableDictionary *tagIndex = [NSMutableDictionary dictionary];

    [branches clean];
    [tags clean];
    [remotes clean];

    void (^localBlock)(NSString *, NSString *) = ^(NSString *name, NSString *commit) {
        XTLocalBranchItem *branch = [[XTLocalBranchItem alloc] initWithTitle:[name lastPathComponent] andSha:commit];
        [branches addchild:branch];
        [refsIndex addObject:branch forKey:branch.sha];
    };

    void (^remoteBlock)(NSString *, NSString *, NSString *) = ^(NSString *remoteName, NSString *branchName, NSString *commit) {
        XTSideBarItem *remote = [remotes getRemote:remoteName];
        if (remote == nil) {
            remote = [[XTSideBarItem alloc] initWithTitle:remoteName];
            [remotes addchild:remote];
        }
        XTRemoteBranchItem *branch = [[XTRemoteBranchItem alloc] initWithTitle:branchName remote:remoteName sha:commit];
        [remote addchild:branch];
        [refsIndex addObject:branch forKey:branch.sha];
    };

    void (^tagBlock)(NSString *, NSString *) = ^(NSString *name, NSString *commit) {
        XTTagItem *tag;
        NSString *tagName = [name lastPathComponent];
        if ([tagName hasSuffix:@"^{}"]) {
            tagName = [tagName substringToIndex:tagName.length - 3];
            tag = [tagIndex objectForKey:tagName];
            tag.sha = commit;
        } else {
            tag = [[XTTagItem alloc] initWithTitle:tagName andSha:commit];
            [tags addchild:tag];
            [tagIndex setObject:tag forKey:tagName];
        }
        [refsIndex addObject:tag forKey:tag.sha];
    };

    [repo readRefsWithLocalBlock:localBlock remoteBlock:remoteBlock tagBlock:tagBlock];
}

- (XTLocalBranchItem *)itemForBranchName:(NSString *)branch {
    XTSideBarItem *branches = [roots objectAtIndex:0];

    for (NSInteger i = 0; i < [branches numberOfChildren]; ++i) {
        XTLocalBranchItem *branchItem = [branches childAtIndex:i];

        if ([branchItem.title isEqual:branch])
            return branchItem;
    }
    return nil;
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    outline = outlineView;
    outlineView.delegate = self;

    NSInteger res = 0;
    if (item == nil) {
        res = [roots count];
    } else if ([item isKindOfClass:[XTSideBarItem class]]) {
        XTSideBarItem *sbItem = (XTSideBarItem *)item;
        res = [sbItem numberOfChildren];
    }
    return res;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    BOOL res = NO;

    if ([item isKindOfClass:[XTSideBarItem class]]) {
        XTSideBarItem *sbItem = (XTSideBarItem *)item;
        res = [sbItem isItemExpandable];
    }
    return res;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    id res = nil;

    if (item == nil) {
        res = [roots objectAtIndex:index];
    } else if ([item isKindOfClass:[XTSideBarItem class]]) {
        XTSideBarItem *sbItem = (XTSideBarItem *)item;
        res = [sbItem childAtIndex:index];
    }
    return res;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([roots containsObject:item]) {
        NSTableCellView *headerView = [outlineView makeViewWithIdentifier:@"HeaderCell" owner:self];

        [headerView.textField setStringValue:[item title]];
        return headerView;
    } else {
        XTSideBarTableCellView *dataView = (XTSideBarTableCellView *)[outlineView makeViewWithIdentifier:@"DataCell" owner:self];

        [dataView.textField setStringValue:[item title]];
        if ([item isKindOfClass:[XTLocalBranchItem class]]) {
            [dataView.imageView setImage:[NSImage imageNamed:@"branch"]];
            if (![item isKindOfClass:[XTRemoteBranchItem class]])
                [dataView.button setHidden:![[item title] isEqualToString:currentBranch]];
        } else if ([item isKindOfClass:[XTTagItem class]]) {
            [dataView.imageView setImage:[NSImage imageNamed:@"tag"]];
        } else {
            [dataView.button setHidden:YES];
            if ([outlineView parentForItem:item] == [roots objectAtIndex:XT_REMOTES])
                [dataView.imageView setImage:[NSImage imageNamed:NSImageNameNetwork]];
        }
        return dataView;
    }
}

#pragma mark - NSOutlineViewDelegate

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    XTSideBarItem *item = [outline itemAtRow:outline.selectedRow];

    if (item.sha != nil)
        repo.selectedCommit = item.sha;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    XTSideBarItem *i = (XTSideBarItem *)item;

    return (i.sha != nil);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
    return [roots containsObject:item];
}

@end
