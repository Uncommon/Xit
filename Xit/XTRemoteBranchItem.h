#import <Foundation/Foundation.h>
#import "XTLocalBranchItem.h"

@interface XTRemoteBranchItem : XTLocalBranchItem {
    NSString *remote;
}

@property (strong) NSString *remote;

- (id)initWithTitle:(NSString *)theTitle remote:(NSString *)remote sha:(NSString *)sha;

@end
