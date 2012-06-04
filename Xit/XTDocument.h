//
//  Xit.h
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import <Cocoa/Cocoa.h>

@class XTRepository;

@interface XTDocument : NSDocument {
    @private
    NSURL *repoURL;
    XTRepository *repo;
}

// XXX TEMP
- (IBAction)reload:(id)sender;

@property (readonly) XTRepository *repository;

@end
