//
//  Xit.h
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import <Cocoa/Cocoa.h>

@class XTSideBarDataSource;

@interface Xit : NSDocument {
    IBOutlet XTSideBarDataSource *sideBarDS;
@private
    NSURL *repoURL;
    NSString *gitCMD;
}

-(NSData *)exectuteGitWithArgs:(NSArray *)args error:(NSError **)error;

@end
