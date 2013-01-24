//
//  XTSideBarDataSource.h
//  Xit
//
//  Created by German Laullon on 17/07/11.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "XTConstants.h"

@class XTRepository;
@class XTLocalBranchItem;

@interface XTSideBarDataSource : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    @private
    XTRepository *repo;
    NSArray *roots;
    NSOutlineView *outline;
    NSString *currentBranch;
    BOOL didInitialExpandGroups;
}

- (void)setRepo:(XTRepository *)repo;
- (void)reload;
- (void)reloadBranches:(NSMutableDictionary *)refsIndex;
- (void)reloadStashes:(NSMutableDictionary *)refsIndex;

- (XTLocalBranchItem *)itemForBranchName:(NSString *)branch;

@property (readonly) NSArray *roots;

@end
