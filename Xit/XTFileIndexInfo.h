#import <Foundation/Foundation.h>

@interface XTFileIndexInfo : NSObject

@property(strong) NSString *name;
@property(strong) NSString *status;

- (id)initWithName:(NSString *)theName andStatus:(NSString *)theStatus;

@end
