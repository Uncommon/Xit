#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class XTRepository;
@class XTStagedDataSource;
@class XTUnstagedDataSource;
@class XTFileIndexInfo;

#import <Cocoa/Cocoa.h>
@interface XTStageViewController
    : NSViewController<DOMEventListener, NSTableViewDelegate> {
  IBOutlet XTStagedDataSource *stageDS;
  IBOutlet XTUnstagedDataSource *unstageDS;
  IBOutlet WebView *web;
  IBOutlet NSTableView *stageTable;
  IBOutlet NSTableView *unstageTable;
  IBOutlet NSButton *commitButton;
  XTRepository *repo;
  NSString *actualDiff;
  BOOL stagedFile;
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
