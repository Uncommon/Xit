#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "XTConstants.h"

@class XTHistoryViewController;
@class XTLocalBranchItem;
@class XTRefFormatter;
@class XTRepository;
@class XTSideBarItem;

/**
  Data source for the sidebar, showing branches, remotes, tags, stashes,
  and submodules.
 */
@interface XTSideBarDataSource : NSObject {
 @private
  NSString *_currentBranch;
  XTSideBarItem *_stagingItem;
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

@property NSOutlineView *outline;
@property (nonatomic) XTRepository *repo;
@property (readonly) NSArray<XTSideBarItem*> *roots;

@end
