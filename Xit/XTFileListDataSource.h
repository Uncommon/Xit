#import <Foundation/Foundation.h>
#import "XTRepository+Parsing.h"

@class XTFileViewController;
@class XTRepository;


/**
  Provides all files from the selected commit's tree, with special icons
  displayed for changed files. Entried are added for deleted files.
 */
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


/**
  Cell view with additional images for changed files.
 */
@interface XTFileCellView : NSTableCellView

@property IBOutlet NSImageView *changeImage;
@property XitChange change;

@end
