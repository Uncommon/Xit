#import <Foundation/Foundation.h>

@class XTRepository;

@interface XTFileListDataSource : NSObject <NSOutlineViewDataSource>
{
    @private
    XTRepository *repo;
    NSTreeNode *root;
    NSOutlineView *table;
}

- (void)setRepo:(XTRepository *)repo;
- (void)reload;

@end
