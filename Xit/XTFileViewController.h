#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@class XTCommitHeaderViewController;
@class XTFileListDataSource;
@class XTRepository;
@class XTTextPreviewController;
@class RBSplitView;

/**
  View controller for the file list and detail view.
 */
@interface XTFileViewController : NSViewController
{
  IBOutlet NSSplitView *_headerSplitView;
  IBOutlet RBSplitView *_splitView;
  IBOutlet NSView *_leftPane, *_rightPane;
  IBOutlet NSOutlineView *_fileListOutline;
  IBOutlet QLPreviewView *_filePreview;
  IBOutlet XTCommitHeaderViewController *_headerController;
  IBOutlet XTFileListDataSource *_fileListDS;
  IBOutlet XTTextPreviewController *_textPreview;

  XTRepository *_repo;
}

@property (strong) IBOutlet NSTabView *previewTabView;

+ (BOOL)fileNameIsText:(NSString*)name;

- (void)setRepo:(XTRepository *)repo;
- (void)refresh;

@end
