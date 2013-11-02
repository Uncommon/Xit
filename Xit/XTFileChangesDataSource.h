#import "XTFileListDataSourceBase.h"

@class XTFileViewController;
@class XTRepository;

/**
  Provides a list of changed files for the selected commit.
 */
@interface XTFileChangesDataSource :
    XTFileListDataSourceBase<NSOutlineViewDataSource>

@property IBOutlet NSOutlineView *outlineView;
@property IBOutlet XTFileViewController *controller;

@end
