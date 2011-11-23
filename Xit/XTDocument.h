//
//  Xit.h
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import <Cocoa/Cocoa.h>

@class XTHistoryViewController;
@class XTStageViewController;
@class XTRepository;
@class XTFileViewController;
@class XTStatusView;

@interface XTDocument : NSDocument {
    IBOutlet XTHistoryViewController *historyView;
    IBOutlet XTStageViewController *stageView;
    IBOutlet XTFileViewController *fileListView;
    IBOutlet NSTabView *tabs;
    IBOutlet NSProgressIndicator *activity;
    IBOutlet XTStatusView *statusView;
    @private
    NSURL *repoURL;
    XTRepository *repo;
}

- (void)loadViewController:(NSViewController *)viewController onTab:(NSInteger)tabId;

// XXX TEMP
- (IBAction)reload:(id)sender;

@end
