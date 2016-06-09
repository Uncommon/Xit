#import <Foundation/Foundation.h>

@interface XTModDateTracker : NSObject {
  NSString *_path;
  NSDate *_lastDate;
}

- (instancetype)initWithPath:(NSString *)filePath;
@property (readonly, copy) NSDate *modDate;
@property (readonly) BOOL hasDateChanged;

@end
