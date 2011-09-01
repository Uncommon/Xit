//
//  Xit.h
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import <Cocoa/Cocoa.h>

@class XTHistoryView;
@class XTStageViewController;
@class XTRepository;

@interface XTDocument : NSDocument {
    IBOutlet XTHistoryView *historyView;
    IBOutlet XTStageViewController *stageView;
    IBOutlet NSTabView *tabs;
    @private
    NSURL *repoURL;
    XTRepository *repo;
}

// XXX TEMP
- (IBAction)reload:(id)sender;

@end
