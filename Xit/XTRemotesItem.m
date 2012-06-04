//
//  XTRemotesItem.m
//  Xit
//
//  Created by glaullon on 7/18/11.
//

#import "XTRemotesItem.h"


@implementation XTRemotesItem

- (id)initWithTitle:(NSString *)theTitle {
    self = [super initWithTitle:theTitle];
    if (self) {
        remotes = [NSMutableDictionary dictionary];
    }

    return self;
}

- (XTSideBarItem *)getRemote:(NSString *)remoteName {
    return [remotes objectForKey:remoteName];
}

- (void)addchild:(XTSideBarItem *)child {
    [super addchild:child];
    [remotes setObject:child forKey:[child title]];
}

- (void)clean {
    [super clean];
    [remotes removeAllObjects];
}
@end
