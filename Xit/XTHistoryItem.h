//
//  XTHistoryItem.h
//  Xit
//
//  Created by German Laullon on 26/07/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PBGraphCellInfo.h"

@interface XTHistoryItem : NSObject <NSCopying>
{
    @private
    NSString *sha;
    NSArray *parents;
    NSString *date;
    NSString *email;
    NSString *subject;
	PBGraphCellInfo *lineInfo;
}

@property(assign) NSString *sha;
@property(assign) NSArray *parents;
@property(assign) NSString *date;
@property(assign) NSString *email;
@property(assign) NSString *subject;
@property(assign) PBGraphCellInfo *lineInfo;

@end
