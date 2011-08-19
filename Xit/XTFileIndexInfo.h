//
//  XTFileIndexInfo.h
//  Xit
//
//  Created by German Laullon on 09/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XTFileIndexInfo : NSObject
{
    @private
    NSString *name;
    NSString *status;
}

@property (assign) NSString *name;
@property (assign) NSString *status;

- (id) initWithName:(NSString *)theName andStatus:(NSString *)theStatus;

@end
