#import "XTFileListDataSourceBase.h"

@class XTFileViewController;
@class XTRepository;

@interface XTFlatFileListDataSourceBase : XTFileListDataSourceBase

@end

/**
  Provides a list of changed files for the selected commit.
 */
@interface XTFileChangesDataSource :
    XTFileListDataSourceBase<NSOutlineViewDataSource>

@end
