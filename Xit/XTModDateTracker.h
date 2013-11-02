#import <Foundation/Foundation.h>

@interface XTModDateTracker : NSObject {
  NSString *_path;
  NSDate *_lastDate;
}

- (id)initWithPath:(NSString *)filePath;
- (NSDate *)modDate;
- (BOOL)hasDateChanged;

@end
