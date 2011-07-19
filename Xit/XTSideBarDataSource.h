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
    XT_BRANCHS=0,
    XT_TAGS=1,
    XT_REMOTES=2
} XTSideBarRootItems;

@interface XTSideBarDataSource : NSObject <NSOutlineViewDataSource>
{
    @private
    Xit *repo;
    NSArray *roots;
}

-(void)setRepo:(Xit *)repo;
-(void)reload;

@end
