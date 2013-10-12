#import <Foundation/Foundation.h>
#import "XTConstants.h"

#import <Cocoa/Cocoa.h>
@interface XTSideBarItem : NSObject {
 @private
  NSString *title;
  NSString *sha;
  NSMutableArray *children;
}

@property(strong) NSString *title;
@property(strong) NSString *sha;
@property(strong) NSMutableArray *children;

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

#import <Cocoa/Cocoa.h>
@interface XTStashItem : XTSideBarItem {
}

@end