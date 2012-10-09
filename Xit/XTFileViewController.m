//
//  XTFileViewController.m
//  Xit
//
//  Created by German Laullon on 15/09/11.
//

#import "XTFileViewController.h"
#import "XTFileListDataSource.h"
#import "XTFileListHistoryDataSource.h"

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
@end
