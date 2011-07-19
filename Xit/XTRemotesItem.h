//
//  XTRemotesItem.h
//  Xit
//
//  Created by glaullon on 7/18/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XTSideBarItem.h"

@interface XTRemotesItem : XTSideBarItem {
@private
    NSMutableDictionary *remotes;
}

-(XTSideBarItem *)getRemote:(NSString *)remoteName;

@end
