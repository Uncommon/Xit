#import <Cocoa/Cocoa.h>

@class XTRepository;

#import <Cocoa/Cocoa.h>
@interface XTDocument : NSDocument {
 @private
  NSURL *repoURL;
  XTRepository *repo;
}

@property(readonly) XTRepository *repository;

@end
