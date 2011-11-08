//
//  XTAppDelegate.m
//  Xit
//
//  Created by David Catmull on 10/13/11.
//

#import "XTAppDelegate.h"
#import "XTDocument.h"

@implementation XTAppDelegate

- (id)init {
    self = [super init];
    if (self) {
        // Initialization code here.
    }

    return self;
}

- (void)openDocument:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    [panel setDelegate:self];
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            for (NSURL *url in [panel URLs]) {
                [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES completionHandler:NULL];
            }
        }
    }];
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)app {
    [self openDocument:nil];
    // Returning YES prevents the app from opening an untitled document on its own.
    return YES;
}

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError {
    NSURL *repoURL = [url URLByAppendingPathComponent:@".git" isDirectory:YES];

    if ([[NSFileManager defaultManager] fileExistsAtPath:[repoURL path]])
        return YES;
    else {
        NSAlert *alert = [NSAlert alertWithMessageText:@"That folder does not contain a Git repository." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];

        [alert beginSheetModalForWindow:[sender window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        return NO;
    }
}

@end
