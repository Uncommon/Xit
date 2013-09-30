#import <Foundation/Foundation.h>
#import "XTRepository+Parsing.h"

@class XTFileViewController;
@class XTRepository;


@interface XTFileListDataSource : NSObject<NSOutlineViewDataSource> {
 @private
  XTRepository *repo;
  IBOutlet XTFileViewController *controller;
  NSTreeNode *root;
  NSDictionary *changeImages;
  NSOutlineView *table;
}

- (void)setRepo:(XTRepository *)repo;
- (void)reload;

@end


@interface XTCommitTreeItem : NSObject

@property NSString *path;
@property XitChange change;

@end


@interface XTFileCellView : NSTableCellView

@property IBOutlet NSImageView *changeImage;
@property XitChange change;

@end
