#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

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
/// Displays a file from a commit.
- (void)loadPath:(NSString*)path
          commit:(NSString*)sha
      repository:(XTRepository*)repository;
/// Displays a workspace file.
- (void)loadUnstagedPath:(NSString*)path
              repository:(XTRepository*)repository;
/// Displays a file from the index.
- (void)loadStagedPath:(NSString*)path
            repository:(XTRepository*)repository;

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

  XTRepository *_repo;
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
@property (readonly) BOOL inStagingView;

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
- (void)refresh;

@end
