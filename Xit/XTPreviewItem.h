#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>

@class XTRepository;

@interface XTPreviewItem : NSObject<QLPreviewItem> {
    NSString *path;
}

@property(retain) XTRepository *repo;
@property(copy, nonatomic) NSString *commitSHA;
@property(copy, nonatomic) NSString *path;
@property(copy, readonly) NSString *tempFolder;
@property(retain, readonly) NSURL *previewItemURL;

@end
