//
//  NSMutableDictionary+MultiObjectForKey.h
//  Xit
//
//  Created by German Laullon on 05/08/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableDictionary (NSMutableDictionary_MultiObjectForKey)

- (void)addObject:(id)anObject forKey:(id)aKey;

@end


@interface NSDictionary (NSDictionary_MultiObjectForKey)

- (NSArray *)objectsForKey:(id)aKey;

@end