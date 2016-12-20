#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "XTFileListDataSourceBase.h"

@class XTCommitHeaderViewController;
@class XTFileChangesDataSource;
@class XTFileDiffController;
@class XTFileTreeDataSource;
@class XTPreviewController;
@class XTRepository;
@class XTTextPreviewController;

@protocol XTFileChangesModel;

extern const CGFloat kChangeImagePadding;

/**
  Interface for a controller that displays file content in some form.
 */
@protocol XTFileContentController <NSObject>

/// Clears the display for when nothing is selected.
- (void)clear;
/// Displays the content from the given file model.
/// @param path The repository-relative file path.
/// @param model The model to read data from.
/// @param staged Whether to show staged content.
- (void)loadPath:(NSString*)path
           model:(id<XTFileChangesModel>)model
          staged:(BOOL)staged NS_SWIFT_NAME(load(path:model:staged:));

@end


/**
  View controller for the file list and detail view.
 */
@interface XTFileViewController : NSViewController <NSOutlineViewDelegate>

@property (weak) IBOutlet NSSplitView *headerSplitView, *fileSplitView;
@property (weak) IBOutlet NSView *leftPane, *rightPane;
@property (weak) IBOutlet NSOutlineView *fileListOutline;
@property (strong) IBOutlet XTFileChangesDataSource *fileChangeDS;
@property (strong) IBOutlet XTFileTreeDataSource *fileListDS;
@property (weak) IBOutlet NSTabView *headerTabView;
@property (strong) IBOutlet NSTabView *previewTabView;
@property (weak) IBOutlet NSSegmentedControl *viewSelector;
@property (weak) IBOutlet NSSegmentedControl *stageSelector;
@property (weak) IBOutlet NSSegmentedControl *previewSelector;
@property (weak) IBOutlet NSSegmentedControl *stageButtons;
@property (weak) IBOutlet NSPopUpButton *actionButton;
@property (weak) IBOutlet NSPathControl *previewPath;
@property (strong) IBOutlet XTCommitHeaderViewController *headerController;
@property (strong) IBOutlet XTFileDiffController *diffController;
@property (strong) IBOutlet XTPreviewController *previewController;
@property (strong) IBOutlet XTTextPreviewController *textController;
@property (weak) IBOutlet QLPreviewView *filePreview;

@property (weak, nonatomic) XTRepository *repo;
@property (readonly) NSDictionary *changeImages;
@property (readonly) XTFileListDataSourceBase<XTFileListDataSource>
    *fileListDataSource;

- (IBAction)changeFileListView:(id)sender;
- (IBAction)changeContentView:(id)sender;
- (IBAction)stageClicked:(id)sender;
- (IBAction)unstageClicked:(id)sender;
- (IBAction)changeStageView:(id)sender;

- (IBAction)stageAll:(id)sender;
- (IBAction)unstageAll:(id)sender;
- (IBAction)showIgnored:(id)sender;
- (IBAction)stageUnstageAll:(NSSegmentedControl*)sender;

- (void)windowDidLoad;
- (void)reload;
- (void)refreshPreview;

@end
