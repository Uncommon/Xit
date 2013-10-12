#import <Foundation/Foundation.h>

#import <Cocoa/Cocoa.h>
@interface NSMutableDictionary (NSMutableDictionary_MultiObjectForKey)

- (void)addObject:(id)anObject forKey:(id)aKey;

@end


#import <Cocoa/Cocoa.h>
@interface NSDictionary (NSDictionary_MultiObjectForKey)

- (NSArray *)objectsForKey:(id)aKey;

@end