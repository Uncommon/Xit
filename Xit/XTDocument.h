#import <Cocoa/Cocoa.h>

@class XTRepository;

@interface XTDocument : NSDocument {
 @private
  NSURL *_repoURL;
  XTRepository *_repo;
}

@property(readonly) XTRepository *repository;

@end
