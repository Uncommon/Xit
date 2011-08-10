//
//  XTSideBarDataSource.h
//  Xit
//
//  Created by German Laullon on 17/07/11.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

@class Xit;

typedef enum {
    XT_BRANCHS = 0,
    XT_TAGS,
    XT_REMOTES,
    XT_STASHES
} XTSideBarRootItems;

@interface XTSideBarDataSource : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    @private
    Xit *repo;
    NSArray *roots;
    NSOutlineView *outline;
}

- (void)setRepo:(Xit *)repo;
- (void)reload;
- (void)reloadBrachs:(NSMutableDictionary *)refsIndex;
- (void)reloadStashes:(NSMutableDictionary *)refsIndex;

@end
