//
//  XTHistoryItem.h
//  Xit
//
//  Created by German Laullon on 26/07/11.
//

#import <Foundation/Foundation.h>
#import "PBGraphCellInfo.h"

@interface XTHistoryItem : NSObject <NSCopying>
{
    @private
    NSString *sha;
    NSMutableArray *parents;
    NSString *date;
    NSString *email;
    NSString *subject;
	PBGraphCellInfo *lineInfo;
    NSUInteger index;
}

@property(assign) NSString *sha;
@property(assign) NSMutableArray *parents;
@property(assign) NSString *date;
@property(assign) NSString *email;
@property(assign) NSString *subject;
@property(assign) PBGraphCellInfo *lineInfo;
@property NSUInteger index;

@end
