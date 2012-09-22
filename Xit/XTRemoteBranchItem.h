//
//  XTRemoteBranchItem.h
//  Xit
//
//  Created by David Catmull on 9/24/11.
//

#import <Foundation/Foundation.h>
#import "XTLocalBranchItem.h"

@interface XTRemoteBranchItem : XTLocalBranchItem {
    NSString *remote;
}

@property (assign) NSString *remote;

- (id)initWithTitle:(NSString *)theTitle remote:(NSString *)remote sha:(NSString *)sha;

@end
