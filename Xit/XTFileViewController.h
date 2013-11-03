#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@class XTCommitHeaderViewController;
@class XTFileChangesDataSource;
@class XTFileListDataSource;
@class XTRepository;
@class XTTextPreviewController;
@class RBSplitView;

extern const CGFloat kChangeImagePadding;

/**
  View controller for the file list and detail view.
 */
@interface XTFileViewController : NSViewController
{
  IBOutlet NSSplitView *headerSplitView;
  IBOutlet RBSplitView *splitView;
  IBOutlet NSView *leftPane, *rightPane;
  IBOutlet NSOutlineView *fileListOutline;
  IBOutlet QLPreviewView *filePreview;
  IBOutlet XTCommitHeaderViewController *headerController;
  IBOutlet XTFileChangesDataSource *_fileChangeDS;
  IBOutlet XTFileListDataSource *fileListDS;
  IBOutlet XTTextPreviewController *textPreview;

  XTRepository *_repo;
}

@property (strong) IBOutlet NSTabView *previewTabView;
@property (weak) IBOutlet NSSegmentedControl *viewSelector;
@property (readonly) NSDictionary *changeImages;

+ (BOOL)fileNameIsText:(NSString*)name;

- (IBAction)changeFileListView:(id)sender;

- (void)setRepo:(XTRepository *)repo;
- (void)refresh;

@end
