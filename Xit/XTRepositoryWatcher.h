#import <Foundation/Foundation.h>

@class XTRepository;

@interface XTRepositoryWatcher : NSObject

+(instancetype)watcherWithRepo:(XTRepository*)repo;
-(instancetype)initWithRepo:(XTRepository*)repo;

@end
