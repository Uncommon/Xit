//
//  XTSideBarDataSource.h
//  Xit
//
//  Created by German Laullon on 17/07/11.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

@class XTRepository;

typedef enum {
    XT_BRANCHES = 0,
    XT_TAGS,
    XT_REMOTES,
    XT_STASHES
} XTSideBarRootItems;

@interface XTSideBarDataSource : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    @private
    XTRepository *repo;
    NSArray *roots;
    NSOutlineView *outline;
}

- (void)setRepo:(XTRepository *)repo;
- (void)reload;
- (void)reloadBrachs:(NSMutableDictionary *)refsIndex;
- (void)reloadStashes:(NSMutableDictionary *)refsIndex;

@end
