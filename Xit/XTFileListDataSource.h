#import <Foundation/Foundation.h>
#import "XTRepository+Parsing.h"

@class XTFileViewController;
@class XTRepository;


@interface XTFileListDataSource : NSObject<NSOutlineViewDataSource> {
 @private
  XTRepository *_repo;
  IBOutlet XTFileViewController *_controller;
  NSTreeNode *_root;
  NSDictionary *_changeImages;
  NSOutlineView *_table;
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
