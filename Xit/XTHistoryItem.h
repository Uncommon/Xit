#import <Foundation/Foundation.h>
#import "PBGraphCellInfo.h"

@class XTRepository;

#import <Cocoa/Cocoa.h>
@interface XTHistoryItem : NSObject<NSCopying> {
 @private
  XTRepository *repo;
  NSString *sha;
  NSString *shortSha;
  NSMutableArray *parents;
  NSDate *date;
  NSString *email;
  NSString *subject;
  PBGraphCellInfo *lineInfo;
  NSUInteger index;
}

@property(strong) XTRepository *repo;
@property(strong) NSString *sha;
@property(strong) NSString *shortSha;
@property(strong) NSMutableArray *parents;
@property(strong) NSDate *date;
@property(strong) NSString *email;
@property(strong) NSString *subject;
@property(strong) PBGraphCellInfo *lineInfo;
@property NSUInteger index;

@end
