#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class XTRepository;
@class XTStagedDataSource;
@class XTUnstagedDataSource;
@class XTFileIndexInfo;

@interface XTStageViewController
    : NSViewController<DOMEventListener, NSTableViewDelegate> {
 @public
  IBOutlet XTStagedDataSource *stageDS;
  IBOutlet XTUnstagedDataSource *unstageDS;
  IBOutlet WebView *web;
  IBOutlet NSTableView *stageTable;
  IBOutlet NSTableView *unstageTable;
  XTRepository *repo;
  NSString *actualDiff;
  BOOL stagedFile;
}

@property(strong) NSString *message;

- (IBAction)commit:(id)sender;

- (void)setRepo:(XTRepository *)newRepo;
- (void)reload;
- (void)showStageFile:(XTFileIndexInfo *)file;
- (void)showUnstageFile:(XTFileIndexInfo *)file;
- (void)unstageChunk:(NSInteger)idx;
- (void)stageChunk:(NSInteger)idx;
- (void)discardChunk:(NSInteger)idx;
- (NSString *)preparePatch:(NSInteger)idx;

- (void)showDiff:(NSString *)diff;
- (DOMHTMLElement *)createButtonWithIndex:(int)index
                                    title:(NSString *)title
                                  fromDOM:(DOMDocument *)dom;

- (void)stagedDoubleClicked:(id)sender;
- (void)unstagedDoubleClicked:(id)sender;

- (NSString *)diffForNewFile:(NSString *)file;

@end
