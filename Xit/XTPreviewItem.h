#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>

@class XTRepository;

/**
  QuickLook preview item for binary file previews.
 */
@interface XTPreviewItem : NSObject<QLPreviewItem> {
  NSString *_path, *_commitSHA;
}

@property(retain) XTRepository *repo;
@property(copy, nonatomic) NSString *commitSHA;
@property(copy, nonatomic) NSString *path;
@property(copy, readonly) NSString *tempFolder;
@property(readonly) NSURL *previewItemURL;

@end
