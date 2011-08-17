//
//  XTStageViewController.h
//  Xit
//
//  Created by German Laullon on 10/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class Xit;
@class XTStagedDataSource;
@class XTUnstagedDataSource;
@class XTFileIndexInfo;

@interface XTStageViewController : NSViewController <DOMEventListener, NSTableViewDelegate>
{
    IBOutlet XTStagedDataSource *stageDS;
    IBOutlet XTUnstagedDataSource *unstageDS;
    IBOutlet WebView *web;
    @private
    IBOutlet NSTableView *stageTable;
    IBOutlet NSTableView *unstageTable;
    Xit *repo;
    NSString *actualDiff;
    BOOL stagedFile;
}

- (void)setRepo:(Xit *)newRepo;
- (void)viewDidLoad;
- (void)reload;
- (void)showStageFile:(XTFileIndexInfo *)file;
- (void)showUnstageFile:(XTFileIndexInfo *)file;
- (void)unstageChunk:(NSInteger)idx;
- (void)stageChunk:(NSInteger)idx;
- (void)discardChunk:(NSInteger)idx;
- (NSString *)preparePatch:(NSInteger)idx;

- (void)showDiff:(NSString *)diff;
- (DOMHTMLElement *)createButtonWithIndex:(int)index title:(NSString *)title fromDOM:(DOMDocument *)dom;

@end
