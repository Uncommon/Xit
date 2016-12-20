#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "XTConstants.h"

@class XTHistoryViewController;
@class XTLocalBranchItem;
@class XTRefFormatter;
@class XTRepository;
@class XTSidebarController;
@class XTSideBarItem;
@class XTSideBarGroupItem;

NS_ASSUME_NONNULL_BEGIN

/**
  Data source for the sidebar, showing branches, remotes, tags, stashes,
  and submodules.
 */
@interface XTSideBarDataSource : NSObject {
  NSString *_currentBranch;
}

- (void)reload;
- (void)loadBranches:(XTSideBarItem*)branches
                tags:(NSMutableArray*)tags
             remotes:(XTSideBarItem*)remotes
           refsIndex:(NSMutableDictionary *)refsIndex;
- (void)loadStashes:(NSMutableArray *)stashes
          refsIndex:(NSMutableDictionary *)refsIndex;

- (void)doubleClick:(id)sender;

@property (weak) IBOutlet XTSidebarController *viewController;
@property (weak) IBOutlet XTRefFormatter *refFormatter;
@property (weak) IBOutlet NSOutlineView *outline;

@property (weak, nonatomic) XTRepository *repo;
@property (readonly) NSArray<XTSideBarGroupItem*> *roots;
@property (readonly) XTSideBarItem *stagingItem;
/// Cached build statuses, keyed on build type and branch name.
@property NSMutableDictionary<NSString*,
                              NSDictionary<NSString*, NSNumber*>*> *buildStatuses;

@property (nullable) NSTimer *buildStatusTimer;
@property (nullable) NSTimer *reloadTimer;

@property (nullable) id<NSObject> teamCityObserver;

@end

NS_ASSUME_NONNULL_END
