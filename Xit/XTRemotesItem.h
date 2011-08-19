//
//  XTRemotesItem.h
//  Xit
//
//  Created by glaullon on 7/18/11.
//

#import <Foundation/Foundation.h>
#import "XTSideBarItem.h"

@interface XTRemotesItem : XTSideBarItem {
    @private
    NSMutableDictionary *remotes;
}

- (XTSideBarItem *) getRemote:(NSString *)remoteName;

@end
