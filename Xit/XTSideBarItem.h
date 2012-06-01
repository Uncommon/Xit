//
//  XTSideBarItem.h
//  Xit
//
//  Created by German Laullon on 17/07/11.
//

#import <Foundation/Foundation.h>
#import "XTSideBarItem.h"

@interface XTSideBarItem : NSObject
{
    @private
    NSString *title;
    NSString *sha;
    NSMutableArray *children;
}

@property (assign) NSString *title;
@property (assign) NSString *sha;

- (id)initWithTitle:(NSString *)theTitle andSha:(NSString *)sha;
- (id)initWithTitle:(NSString *)theTitle;
- (NSInteger)numberOfChildren;
- (id)childAtIndex:(NSInteger)index;
- (void)addchild:(XTSideBarItem *)child;
- (BOOL)isItemExpandable;
- (void)clean;
- (NSString *)badge;
@end
