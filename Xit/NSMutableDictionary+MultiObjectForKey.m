//
//  NSMutableDictionary+MultiObjectForKey.m
//  Xit
//
//  Created by German Laullon on 05/08/11.
//

#import "NSMutableDictionary+MultiObjectForKey.h"

@implementation NSMutableDictionary (NSMutableDictionary_MultiObjectForKey)

- (void) addObject:(id)anObject forKey:(id)aKey {
    NSMutableArray * array = [self objectForKey:aKey];

    if (array == nil) {
        array = [NSMutableArray array];
        [self setObject:array forKey:aKey];
    }
    [array addObject:anObject];
}

@end

@implementation NSDictionary (NSDictionary_MultiObjectForKey)

- (NSArray *) objectsForKey:(id)aKey {
    return (NSMutableArray *)[self objectForKey:aKey];
}

@end