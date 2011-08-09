//
//  XTHistoryView.h
//  Xit
//
//  Created by German Laullon on 05/08/11.
//

#import <Cocoa/Cocoa.h>

@class Xit;

@class XTSideBarDataSource;
@class XTHistoryDataSource;
@class XTCommitViewController;

@interface XTHistoryView : NSViewController
{
    IBOutlet XTSideBarDataSource *sideBarDS;
    IBOutlet XTHistoryDataSource *historyDS;
    IBOutlet XTCommitViewController *commitViewController;
    IBOutlet NSView *commitView;
    IBOutlet NSSplitView *sidebarSplitView;
    IBOutlet NSSplitView *mainSplitView;
    IBOutlet NSTableView *table;
    @private
    Xit *repo;
    NSTextField *stickyRow;
}

- (void)setRepo:(Xit *)newRepo;
- (void)viewDidLoad;
-(void)tableChanges:(NSNotification*)aNotification;

-(IBAction)toggleLayout:(id)sender;
-(IBAction)toggleSideBar:(id)sender;

@end
