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
    NSMutableArray *childrens;
}

@property(readonly) NSString *title;
@property(readonly) NSString *sha;

- (id)initWithTitle:(NSString *)theTitle andSha:(NSString *)sha;
- (id)initWithTitle:(NSString *)theTitle;
- (NSInteger)numberOfChildrens;
- (id)children:(NSInteger)index;
- (void)addchildren:(XTSideBarItem *)child;
- (BOOL)isItemExpandable;
- (void)clean;
@end
