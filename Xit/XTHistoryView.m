//
//  XTHistoryView.m
//  Xit
//
//  Created by German Laullon on 05/08/11.
//

#import "XTHistoryView.h"
#import "Xit.h"
#import "XTSideBarDataSource.h"
#import "XTCommitViewController.h"

@implementation XTHistoryView

+ (id)viewController {
    return [[[self alloc] initWithNibName:NSStringFromClass([self class]) bundle:nil] autorelease];
}

- (void)loadView {
    [super loadView];
    [self viewDidLoad];
}

- (void)viewDidLoad {
    NSLog(@"viewDidLoad");
    
    //Sticky row
    
    [table setPostsBoundsChangedNotifications:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(tableChanges:)
                                                 name:NSViewBoundsDidChangeNotification 
                                               object:nil];
}

-(void)tableChanges:(NSNotification*)aNotification
{
    NSRect b=[[table superview] bounds];
    NSRange rows=[table rowsInRect:b];
    NSInteger sel=table.selectedRow;
    if(stickyRow==nil){
        NSRect f=[[table headerView] frame];
        f.origin.y+=f.size.height;
        stickyRow=[[NSTextField alloc] initWithFrame:f];  
        [[[table superview] superview] addSubview:stickyRow];
    }

    if(rows.location>=sel){
        NSCell *cell=[[table preparedCellAtColumn:0 row:sel] copy];
        [stickyRow setCell:cell];
        [stickyRow drawCellInside:cell];
        [stickyRow setHidden:NO];
    }else if((rows.location+rows.length)<sel){
        NSCell *cell=[[table preparedCellAtColumn:0 row:sel] copy];
        [stickyRow setCell:cell];
        [stickyRow drawCellInside:cell];
        [stickyRow setHidden:NO];
    }else{
        [stickyRow setHidden:YES];
    }
}

- (void)setRepo:(Xit *)newRepo
{
    repo=newRepo;
    [sideBarDS setRepo:newRepo];
    [historyDS setRepo:newRepo];
    [commitViewController setRepo:newRepo];
    [[commitViewController view] setFrame:NSMakeRect(0, 0, [commitView frame].size.width, [commitView frame].size.height)];    
    [commitView addSubview:[commitViewController view]];
}

-(IBAction)toggleLayout:(id)sender
{
    //TODO: improve it
    NSLog(@"toggleLayout, %lu,%d",((NSButton *)sender).state,(((NSButton *)sender).state==1));
    [mainSplitView setVertical:(((NSButton *)sender).state==1)];
    [mainSplitView adjustSubviews];
}

-(IBAction)toggleSideBar:(id)sender
{
    //TODO: improve it
    NSLog(@"toggleSideBar, %lu",((NSButton *)sender).state);
    [sidebarSplitView setPosition:(1-((NSButton *)sender).state)*180 ofDividerAtIndex:0 ];
}

@end
