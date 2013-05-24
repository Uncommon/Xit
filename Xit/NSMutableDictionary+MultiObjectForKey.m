#import "NSMutableDictionary+MultiObjectForKey.h"

@implementation NSMutableDictionary (NSMutableDictionary_MultiObjectForKey)

- (void)addObject:(id)anObject forKey:(id)aKey {
    NSMutableArray *array = self[aKey];

    if (array == nil) {
        array = [NSMutableArray array];
        self[aKey] = array;
    }
    [array addObject:anObject];
}

@end

@implementation NSDictionary (NSDictionary_MultiObjectForKey)

- (NSArray *)objectsForKey:(id)aKey {
    return (NSMutableArray *)self[aKey];
}

@end