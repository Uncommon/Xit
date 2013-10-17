#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>

@class XTRepository;

#import <Cocoa/Cocoa.h>
@interface XTPreviewItem : NSObject<QLPreviewItem> {
  NSString *path, *commitSHA;
}

@property(retain) XTRepository *repo;
@property(copy, nonatomic) NSString *commitSHA;
@property(copy, nonatomic) NSString *path;
@property(copy, readonly) NSString *tempFolder;
@property(readonly) NSURL *previewItemURL;

@end
