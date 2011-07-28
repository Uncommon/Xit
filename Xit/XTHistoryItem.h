//
//  XTHistoryItem.h
//  Xit
//
//  Created by German Laullon on 26/07/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XTHistoryItem : NSObject
{
    @private
    NSString *commit;
    NSString *date;
    NSString *email;
    NSString *subject;
}

@property(assign) NSString *commit;
@property(assign) NSString *date;
@property(assign) NSString *email;
@property(assign) NSString *subject;

@end
