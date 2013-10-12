#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "XTConstants.h"

@class XTHistoryViewController;
@class XTLocalBranchItem;
@class XTRefFormatter;
@class XTRepository;
@class XTSideBarItem;

#import <Cocoa/Cocoa.h>
@interface XTSideBarDataSource
    : NSObject<NSOutlineViewDataSource, NSOutlineViewDelegate> {
 @private
  XTRepository *repo;
  NSArray *roots;
  NSOutlineView *outline;
  NSString *currentBranch;
  IBOutlet XTHistoryViewController *viewController;
  IBOutlet XTRefFormatter *refFormatter;
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
