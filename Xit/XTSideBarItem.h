#import <Foundation/Foundation.h>
#import "XTConstants.h"

@interface XTSideBarItem : NSObject

@property(strong) NSString *title;
@property(strong) NSString *sha;
@property(strong) NSMutableArray<XTSideBarItem*> *children;

- (id)initWithTitle:(NSString *)theTitle andSha:(NSString *)sha;
- (id)initWithTitle:(NSString *)theTitle;

- (NSInteger)numberOfChildren;
- (id)childAtIndex:(NSInteger)index;
- (void)addchild:(XTSideBarItem *)child;
- (BOOL)isItemExpandable;

- (void)clean;
- (NSString *)badge;
- (XTRefType)refType;

@end

@interface XTStashItem : XTSideBarItem {
}

@end
