//
//  XTFileViewController.h
//  Xit
//
//  Created by German Laullon on 15/09/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XTRepository.h"
#import "XTFileListDataSource.h"

@interface XTFileViewController : NSViewController <NSOutlineViewDelegate> {
    XTFileListDataSource *fileListDS;
    @private
    XTRepository *repo;
}

@property (assign) IBOutlet XTFileListDataSource *fileListDS;

- (void)setRepo:(XTRepository *)newRepo;

@end
