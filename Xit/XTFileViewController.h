#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@class XTCommitHeaderViewController;
@class XTFileListDataSource;
@class XTRepository;
@class XTTextPreviewController;
@class RBSplitView;

@interface XTFileViewController : NSViewController
{
  IBOutlet RBSplitView *splitView;
  IBOutlet NSView *leftPane, *rightPane;
  IBOutlet NSOutlineView *fileListOutline;
  IBOutlet QLPreviewView *filePreview;
  IBOutlet XTCommitHeaderViewController *headerController;
  IBOutlet XTFileListDataSource *fileListDS;
  IBOutlet XTTextPreviewController *textPreview;

  XTRepository *repo;
}

@property (strong) IBOutlet NSTabView *previewTabView;

+ (BOOL)fileNameIsText:(NSString*)name;

- (void)setRepo:(XTRepository *)repo;
- (void)refresh;

@end
