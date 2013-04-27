#import <Cocoa/Cocoa.h>

@class XTRepository;

@interface XTDocument : NSDocument {
    @private
    NSURL *repoURL;
    XTRepository *repo;
}

@property (readonly) XTRepository *repository;

@end
