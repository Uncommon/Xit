#import "XTRepository+Parsing.h"

@class XTWindowController;
@class XTFileChange;
@class XTFileViewController;
@class XTRepository;

/**
  Abstract base class for file list data sources.
 */
@interface XTFileListDataSourceBase : NSObject<NSOutlineViewDataSource>

@property IBOutlet NSOutlineView *outlineView;
@property IBOutlet XTFileViewController *controller;
@property(weak, nonatomic) XTRepository *repository;
@property(nonatomic) XTWindowController *winController;
@property(readonly, nonatomic) BOOL isHierarchical;


/// Get the change value used for display because in some cases we want to
/// make sure an icon is displayed for unmodified files.
+ (XitChange)transformDisplayChange:(XitChange)change;

@end


/**
  Methods that a file list data source must implement.
 */
@protocol XTFileListDataSource <NSObject>

@property (getter=isHierarchical, readonly) BOOL hierarchical;

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
/// The row index is stored so we know where button clicks come from.
@property NSInteger row;

@end