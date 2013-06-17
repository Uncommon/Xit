#import <ObjectiveGit/ObjectiveGit.h>

typedef void (^GTRepositoryRelativeStatusBlock)(
    NSString *path, GTRepositoryFileStatus status, BOOL *stop);

@interface GTRepository (Xit)

// -[GTRepository enumerateFileStatusUsingBlock:] yields URLs with absolute
// paths, but other calls only take paths relative to the repository.
- (void)enumerateRelativeFileStatusUsingBlock:
    (GTRepositoryRelativeStatusBlock)block;

@end
