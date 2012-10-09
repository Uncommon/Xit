//
//  XTFileIndexInfo.h
//  Xit
//
//  Created by German Laullon on 09/08/11.
//

#import <Foundation/Foundation.h>

@interface XTFileIndexInfo : NSObject
{
    @private
    NSString *name;
    NSString *status;
}

@property (strong) NSString *name;
@property (strong) NSString *status;

- (id)initWithName:(NSString *)theName andStatus:(NSString *)theStatus;

@end
