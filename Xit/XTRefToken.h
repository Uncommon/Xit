#import <Foundation/Foundation.h>
#import "XTConstants.h"

@class XTRepository;
@class XTSideBarItem;

@interface XTRefToken : NSObject

+ (void)drawTokenForRefType:(XTRefType)type text:(NSString *)text rect:(NSRect)rect;
+ (CGFloat)rectWidthForText:(NSString *)text;
+ (XTRefType)typeForRefName:(NSString *)ref inRepository:(XTRepository *)repo;

@end
