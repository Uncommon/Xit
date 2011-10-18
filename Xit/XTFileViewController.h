//
//  XTFileViewController.h
//  Xit
//
//  Created by German Laullon on 15/09/11.
//

#import <Cocoa/Cocoa.h>
#import "XTRepository.h"
#import "XTTrackingTableDelegate.h"

@class XTFileListDataSource;
@class XTFileListHistoryDataSource;
@class XTCommitDetailsViewController;

@interface XTFileViewController : NSViewController <NSOutlineViewDelegate, NSTableViewDelegate, XTTrackingTableDelegate> {
    IBOutlet XTFileListDataSource *fileListDS;
    IBOutlet XTFileListHistoryDataSource *fileListHistoryDS;
    @private
    IBOutlet XTCommitDetailsViewController *commitView;
    XTRepository *repo;
    IBOutlet NSPopover *popover;
    IBOutlet NSPathControl *path;
    IBOutlet NSPathControl *filePath;
}

- (void)setRepo:(XTRepository *)newRepo;

@end
