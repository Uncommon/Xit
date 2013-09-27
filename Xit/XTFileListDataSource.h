#import <Foundation/Foundation.h>

@class XTFileViewController;
@class XTRepository;

@interface XTFileListDataSource : NSObject<NSOutlineViewDataSource> {
 @private
  XTRepository *repo;
  IBOutlet XTFileViewController *controller;
  NSTreeNode *root;
  NSDictionary *changes;
  NSDictionary *changeImages;
  NSOutlineView *table;
}

- (void)setRepo:(XTRepository *)repo;
- (void)reload;

@end


@interface XTFileCellView : NSTableCellView

@property IBOutlet NSImageView *changeImage;

@end
