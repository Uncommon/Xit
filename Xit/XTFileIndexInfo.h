#import <Foundation/Foundation.h>

#import <Cocoa/Cocoa.h>
@interface XTFileIndexInfo : NSObject {
 @private
}

@property(strong) NSString *name;
@property(strong) NSString *status;

- (id)initWithName:(NSString *)theName andStatus:(NSString *)theStatus;

@end
