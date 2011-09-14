//
//  XTFileListDataSource.h
//  Xit
//
//  Created by German Laullon on 13/09/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XTRepository;

@interface XTFileListDataSource : NSObject <NSOutlineViewDataSource>
{
    @private
    XTRepository *repo;
    NSMutableArray *roots;
}

- (void)setRepo:(XTRepository *)repo;
- (void)reload;

@end
