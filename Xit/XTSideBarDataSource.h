#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "XTConstants.h"

@class XTHistoryViewController;
@class XTLocalBranchItem;
@class XTRefFormatter;
@class XTRepository;
@class XTSideBarItem;
@class XTSideBarGroupItem;

@protocol BOSResourceObserver;

/**
  Data source for the sidebar, showing branches, remotes, tags, stashes,
  and submodules.
 */
@interface XTSideBarDataSource : NSObject<BOSResourceObserver> {
  NSString *_currentBranch;
}

- (void)reload;
- (void)loadBranches:(XTSideBarItem*)branches
                tags:(NSMutableArray*)tags
             remotes:(XTSideBarItem*)remotes
           refsIndex:(NSMutableDictionary *)refsIndex;
- (void)loadStashes:(NSMutableArray *)stashes
          refsIndex:(NSMutableDictionary *)refsIndex;

- (XTSideBarItem *)itemNamed:(NSString *)name inGroup:(NSInteger)groupIndex;

@property (weak) IBOutlet XTHistoryViewController *viewController;
@property (weak) IBOutlet XTRefFormatter *refFormatter;
@property (weak) IBOutlet NSOutlineView *outline;

@property (nonatomic) XTRepository *repo;
@property (readonly) NSArray<XTSideBarGroupItem*> *roots;
@property (readonly) XTSideBarItem *stagingItem;

@end
