#import "XTPreviewItem.h"
#import "XTRepository+Parsing.h"

@interface XTPreviewItem ()

@property (readwrite) NSURL *previewItemURL;

@end


@implementation XTPreviewItem

@synthesize previewItemURL;
@synthesize repo;
@synthesize tempFolder;

- (id)init {
    if ((self = [super init]) != nil) {
        NSString *tempDir = NSTemporaryDirectory();
        NSString *tempTemplate = [tempDir stringByAppendingPathComponent:@"xtpreviewXXXXXX"];
        const char *templateStr = [tempTemplate cStringUsingEncoding:NSUTF8StringEncoding];
        char *template = malloc(strlen(templateStr) + 1);

        strcpy(template, templateStr);

        const char *tempPath = mkdtemp(template);

        if (tempPath != NULL)
            tempFolder = @(tempPath);
        free(template);
    }
    return self;
}

- (NSString *)tempFilePath {
    return [tempFolder stringByAppendingPathComponent:[self.path lastPathComponent]];
}

- (void)deleteTempFile {
    const char *tempPath = [[self tempFilePath] cStringUsingEncoding:NSUTF8StringEncoding];

    if (tempPath != NULL)
        unlink(tempPath);
}

- (void)dealloc {
    [self deleteTempFile];
    rmdir([tempFolder cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (void)remakeTempFile {
    [self deleteTempFile];
    self.previewItemURL = nil;

    if ((self.path != nil) && (self.commitSHA != nil)) {
        NSData *contents = [self.repo contentsOfFile:self.path atCommit:self.commitSHA];

        if (contents != nil) {
            NSString *tempFilePath = [self tempFilePath];

            [contents writeToFile:tempFilePath atomically:NO];
            self.previewItemURL = [NSURL fileURLWithPath:tempFilePath];
        }
    }
}

- (void)setPath:(NSString *)newPath {
    if (![newPath isEqualToString:self->path]) {
        self->path = newPath;
        [self remakeTempFile];
    }
}

- (NSString *)path {
    return path;
}

- (void)setCommitSHA:(NSString *)newSHA {
    if (![newSHA isEqualToString:self->commitSHA]) {
        self->commitSHA = newSHA;
        [self remakeTempFile];
    }
}

- (NSString *)commitSHA {
    return commitSHA;
}

@end
