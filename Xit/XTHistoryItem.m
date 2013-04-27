#import "XTHistoryItem.h"

@implementation XTHistoryItem

@synthesize repo;
@synthesize sha;
@synthesize shortSha;
@synthesize parents;
@synthesize date;
@synthesize email;
@synthesize subject;
@synthesize lineInfo;
@synthesize index;

- (id)init {
    self = [super init];
    if (self) {
        self.parents = [NSMutableArray array];
    }

    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}
@end
