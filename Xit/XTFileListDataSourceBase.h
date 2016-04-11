#import "XTRepository+Parsing.h"

@class XTDocController;
@class XTFileChange;
@class XTFileViewController;
@class XTRepository;

/**
  Abstract base class for file list data sources.
 */
@interface XTFileListDataSourceBase :
    NSObject<NSOutlineViewDataSource>

@property IBOutlet NSOutlineView *outlineView;
@property IBOutlet XTFileViewController *controller;
@property(nonatomic) XTRepository *repository;
@property(nonatomic) XTDocController *docController;
@property(readonly, nonatomic) BOOL isHierarchical;

- (void)reload;
- (XTFileChange*)fileChangeAtRow:(NSInteger)row;
- (NSString*)pathForItem:(id)item;
- (XitChange)changeForItem:(id)item;
- (XitChange)unstagedChangeForItem:(id)item;

@end


/**
  Cell view with custom drawing for deleted files.
 */
@interface XTFileCellView : NSTableCellView

/// The change is stored to improve drawing of selected deleted files.
@property XitChange change;

@end


/**
  Cell view with a button rather than an image.
 */
@interface XTTableButtonView : NSTableCellView

@property (assign) IBOutlet NSButton *button;

@end