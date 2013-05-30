#import <Foundation/Foundation.h>

@interface XTModDateTracker : NSObject {
  NSString *path;
  NSDate *lastDate;
}

- (id)initWithPath:(NSString *)filePath;
- (NSDate *)modDate;
- (BOOL)hasDateChanged;

@end
