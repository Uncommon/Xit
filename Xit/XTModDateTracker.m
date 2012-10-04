//
//  XTModDateTracker.m
//  Xit
//
//  Created by David Catmull on 9/26/12.
//
//

#import "XTModDateTracker.h"

@implementation XTModDateTracker

- (id)initWithPath:(NSString *)filePath {
    self = [super init];
    if (self == nil)
        return nil;
    path = [filePath copy];
    lastDate = [[self modDate] copy];
    return self;
}

- (NSDate *)modDate {
    NSError *error = nil;
    NSDictionary *info = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];

    return [info objectForKey:NSFileModificationDate];
}

- (BOOL)hasDateChanged {
    NSDate *newDate = [self modDate];

    if (![newDate isEqual:lastDate]) {
        lastDate = [newDate copy];
        return YES;
    }
    return NO;
}

@end
