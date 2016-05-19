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
@interface XTSideBarDataSource
    : NSObject<NSOutlineViewDataSource, NSOutlineViewDelegate> {
 @private
  XTRepository *_repo;
  NSOutlineView *_outline;
  NSString *_currentBranch;
  XTSideBarItem *_stagingItem;
  IBOutlet XTHistoryViewController *_viewController;
  IBOutlet XTRefFormatter *_refFormatter;
}

- (void)setRepo:(XTRepository *)repo;
- (void)reload;
- (void)loadBranches:(NSMutableArray *)branches
                tags:(NSMutableArray *)tags
             remotes:(NSMutableArray *)remotes
           refsIndex:(NSMutableDictionary *)refsIndex;
- (void)loadStashes:(NSMutableArray *)stashes
          refsIndex:(NSMutableDictionary *)refsIndex;

- (XTSideBarItem *)itemNamed:(NSString *)name inGroup:(NSInteger)groupIndex;

@property(readonly) NSArray *roots;

@end
