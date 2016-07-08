#import <Cocoa/Cocoa.h>

@class XTRepository;

@interface XTDocument : NSDocument {
 @private
  NSURL *_repoURL;
}

@property(readonly) XTRepository *repository;

@end
