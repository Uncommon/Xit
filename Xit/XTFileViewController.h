//
//  XTFileViewController.h
//  Xit
//
//  Created by German Laullon on 15/09/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XTRepository.h"

@class XTFileListDataSource;
@class XTFileListHistoryDataSource;

@interface XTFileViewController : NSViewController <NSOutlineViewDelegate> {
    IBOutlet XTFileListDataSource *fileListDS;
    IBOutlet XTFileListHistoryDataSource *fileListHistoryDS;
    @private
    XTRepository *repo;
}

- (void)setRepo:(XTRepository *)newRepo;

@end
