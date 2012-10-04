//
//  XTModDateTracker.h
//  Xit
//
//  Created by David Catmull on 9/26/12.
//
//

#import <Foundation/Foundation.h>

@interface XTModDateTracker : NSObject {
    NSString *path;
    NSDate *lastDate;
}

- (id)initWithPath:(NSString *)filePath;
- (NSDate *)modDate;
- (BOOL)hasDateChanged;

@end
