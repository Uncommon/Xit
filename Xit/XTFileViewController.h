#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "Xit-Swift.h"

@class XTCommitHeaderViewController;
@class XTFileChangesDataSource;
@class XTFileDiffController;
@class XTFileTreeDataSource;
@class XTPreviewController;
@class XTRepository;
@class XTTextPreviewController;

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
          staged:(BOOL)staged;

@end


/**
  View controller for the file list and detail view.
 */
@interface XTFileViewController : NSViewController <NSOutlineViewDelegate>
{
  IBOutlet NSSplitView *_headerSplitView, *_fileSplitView;
  IBOutlet NSView *_leftPane, *_rightPane;
  IBOutlet NSOutlineView *_fileListOutline;
  IBOutlet QLPreviewView *_filePreview;
  IBOutlet XTCommitHeaderViewController *_headerController;
  IBOutlet XTFileChangesDataSource *_fileChangeDS;
  IBOutlet XTFileTreeDataSource *_fileListDS;
  IBOutlet XTTextPreviewController *_textController;

  __weak XTRepository *_repo;
}

@property (weak) IBOutlet NSTabView *headerTabView;
@property (strong) IBOutlet NSTabView *previewTabView;
@property (weak) IBOutlet NSSegmentedControl *viewSelector;
@property (weak) IBOutlet NSSegmentedControl *stageSelector;
@property (weak) IBOutlet NSSegmentedControl *previewSelector;
@property (weak) IBOutlet NSPopUpButton *actionButton;
@property (weak) IBOutlet NSPathControl *previewPath;
@property (strong) IBOutlet XTFileDiffController *diffController;
@property (strong) IBOutlet XTPreviewController *previewController;
@property (readonly) NSDictionary *changeImages;

- (IBAction)changeFileListView:(id)sender;
- (IBAction)changeContentView:(id)sender;
- (IBAction)stageClicked:(id)sender;
- (IBAction)unstageClicked:(id)sender;
- (IBAction)changeStageView:(id)sender;

- (IBAction)stageAll:(id)sender;
- (IBAction)unstageAll:(id)sender;
- (IBAction)showIgnored:(id)sender;

- (void)windowDidLoad;
- (void)setRepo:(XTRepository *)repo;
- (void)reload;
- (void)refreshPreview;

@end
