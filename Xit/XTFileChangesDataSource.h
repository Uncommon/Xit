#import "XTFileListDataSourceBase.h"

/**
  Provides a list of changed files for the selected commit.
 */
@interface XTFileChangesDataSource : XTFileListDataSourceBase
    <XTFileListDataSource, NSOutlineViewDataSource>

@end
