#import <Foundation/Foundation.h>
#import "XTLocalBranchItem.h"

#import <Cocoa/Cocoa.h>
@interface XTRemoteBranchItem : XTLocalBranchItem {
}

@property(strong) NSString *remote;

- (id)initWithTitle:(NSString *)theTitle
             remote:(NSString *)remote
                sha:(NSString *)sha;

@end
