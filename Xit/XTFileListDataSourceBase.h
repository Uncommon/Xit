#import <Foundation/Foundation.h>

@class XTFileChange;
@class XTRepository;

@interface XTFileListDataSourceBase : NSObject

@property(nonatomic) XTRepository *repository;

- (void)reload;
- (XTFileChange*)fileChangeAtRow:(NSInteger)row;

@end
