//
//  XTFileViewController.h
//  Xit
//
//  Created by German Laullon on 15/09/11.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "XTRepository.h"
#import "XTTrackingTableDelegate.h"

@class XTFileListDataSource;
@class XTFileListHistoryDataSource;
@class XTCommitDetailsViewController;

@interface XTFileViewController : NSViewController <NSOutlineViewDelegate, NSTableViewDelegate, XTTrackingTableDelegate> {
    IBOutlet XTFileListDataSource *fileListDS;
    IBOutlet XTFileListHistoryDataSource *fileListHistoryDS;
    IBOutlet XTFileListHistoryDataSource *fileHistoryDS;
    @private
    IBOutlet XTCommitDetailsViewController *commitView;
    XTRepository *repo;
    IBOutlet NSPopover *popover;
    IBOutlet NSPathControl *path;
    IBOutlet NSPathControl *filePath;
    IBOutlet WebView *web;
    NSString *fileName;
    NSPathControl *displayFileMenu;
    NSPathComponentCell *menuPC;
    NSInteger viewMode;
}

- (void)setRepo:(XTRepository *)newRepo;
- (IBAction)displayFileMenu:(id)sender;

@end
