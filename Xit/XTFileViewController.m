//
//  XTFileViewController.m
//  Xit
//
//  Created by German Laullon on 15/09/11.
//

#import "XTFileViewController.h"
#import "XTHistoryItem.h"

@implementation XTFileViewController

- (NSString *)nibName {
    NSLog(@"nibName: %@ (%@)", [super nibName], [self class ]);
    return NSStringFromClass([self class ]);
}

- (void)setRepo:(XTRepository *)newRepo {
    repo = newRepo;
    [fileListDS setRepo:repo];
    [fileListHistoryDS setRepo:repo];
}

#pragma mark - NSOutlineViewDelegate
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSTableCellView *cell = [outlineView makeViewWithIdentifier:@"fileCell" owner:self];
    NSTreeNode *node = (NSTreeNode *)item;
    NSString *fileName = (NSString *)node.representedObject;

    // TODO: cache the file icon extending NSTreeNode....
    cell.imageView.image = [[NSWorkspace sharedWorkspace] iconForFile:[repo.repoURL.path stringByAppendingPathComponent:fileName]];
    cell.textField.stringValue = [fileName lastPathComponent];

    return cell;
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    NSLog(@"%@", aNotification);
    XTHistoryItem *item = [[fileListHistoryDS items] objectAtIndex:((NSTableView *)aNotification.object).selectedRow];
    repo.selectedCommit = item.sha;
}

// TODO: bad....
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    NSTextFieldCell *cell = aCell;
    if ([aTableView mouseOverRow] == rowIndex) {
        cell.backgroundColor = [NSColor selectedMenuItemColor];
        cell.drawsBackground = YES;
    } else {
        cell.backgroundColor = [NSColor controlBackgroundColor];
        cell.drawsBackground = NO;
    }

}


@end
