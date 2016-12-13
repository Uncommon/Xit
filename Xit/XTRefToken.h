#import <Foundation/Foundation.h>
#import "XTConstants.h"

@class XTRepository;
@class XTSideBarItem;

NS_ASSUME_NONNULL_BEGIN

/// Class that holds methods for drawing reference tokens.
@interface XTRefToken : NSObject

+ (void)drawTokenForRefType:(XTRefType)type
                       text:(NSString *)text
                       rect:(NSRect)rect
                       NS_SWIFT_NAME(drawToken(refType:text:rect:));
+ (CGFloat)rectWidthForText:(NSString *)text NS_SWIFT_NAME(rectWidth(text:));

@end

NS_ASSUME_NONNULL_END
