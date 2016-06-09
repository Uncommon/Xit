#import <Foundation/Foundation.h>
#import "XTLocalBranchItem.h"

@interface XTRemoteBranchItem : XTLocalBranchItem

@property(strong) NSString *remote;

- (instancetype)initWithTitle:(NSString *)theTitle
             remote:(NSString *)remote
                sha:(NSString *)sha NS_DESIGNATED_INITIALIZER;

@end
