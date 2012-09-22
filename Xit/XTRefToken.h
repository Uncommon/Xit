//
//  XTRefToken.h
//  Xit
//
//  Created by David Catmull on 9/13/12.
//

#import <Foundation/Foundation.h>

typedef enum {
    XTRefTypeBranch,
    XTRefTypeActiveBranch,
    XTRefTypeRemote,
    XTRefTypeTag,
    XTRefTypeUnknown
} XTRefType;

@class XTRepository;
@class XTSideBarItem;

@interface XTRefToken : NSObject

+ (void)drawTokenForRefType:(XTRefType)type text:(NSString *)text rect:(NSRect)rect;
+ (CGFloat)rectWidthForText:(NSString *)text;
+ (XTRefType)typeForItem:(XTSideBarItem *)item inRepository:(XTRepository *)repo;

@end
