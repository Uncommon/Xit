#import <Foundation/Foundation.h>

@class XTFileChange;

@interface XTFileListDataSourceBase : NSObject

- (XTFileChange*)fileChangeAtRow:(NSInteger)row;

@end
