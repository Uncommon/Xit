#import <Cocoa/Cocoa.h>
#import "XTRepository.h"

@class XTFileListDataSource;
@class XTFileListHistoryDataSource;

@interface XTFileViewController : NSViewController<NSOutlineViewDelegate> {
  IBOutlet XTFileListDataSource *fileListDS;
  IBOutlet XTFileListHistoryDataSource *fileListHistoryDS;
 @private
  XTRepository *repo;
}

- (void)setRepo:(XTRepository *)newRepo;

@end
