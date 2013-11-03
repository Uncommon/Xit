#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class XTRepository;
@class XTStagedDataSource;
@class XTUnstagedDataSource;
@class XTFileIndexInfo;

@interface XTStageViewController
    : NSViewController<DOMEventListener, NSTableViewDelegate> {
  IBOutlet XTStagedDataSource *_stageDS;
  IBOutlet XTUnstagedDataSource *_unstageDS;
  IBOutlet WebView *_web;
  IBOutlet NSTableView *_stageTable;
  IBOutlet NSTableView *_unstageTable;
  IBOutlet NSButton *_commitButton;
  XTRepository *_repo;
  NSString *_actualDiff;
  BOOL _stagedFile;
}

@property(strong) NSString *message;
@property(readonly) XTStagedDataSource *stageDS;
@property(readonly) XTUnstagedDataSource *unstageDS;
@property(readonly) NSTableView *unstageTable;

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
