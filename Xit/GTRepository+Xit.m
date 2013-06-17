#import "GTRepository+Xit.h"

struct gitPayload {
	__unsafe_unretained GTRepository *repository;
	__unsafe_unretained GTRepositoryRelativeStatusBlock block;
};

static int file_status_callback(
    const char *relativeFilePath, unsigned int gitStatus, void *rawPayload)
{
	struct gitPayload *payload = rawPayload;

	BOOL stop = NO;
	payload->block(@(relativeFilePath), gitStatus, &stop);

	return stop ? GIT_ERROR : GIT_OK;
}

@implementation GTRepository (Xit)

// -[GTRepository enumerateFileStatusUsingBlock:] yields URLs with absolute
// paths, but other calls only take paths relative to the repository.
- (void)enumerateRelativeFileStatusUsingBlock:
    (GTRepositoryRelativeStatusBlock)block
{
	NSParameterAssert(block != NULL);

	struct gitPayload fileStatusPayload;

	fileStatusPayload.repository = self;
	fileStatusPayload.block = block;

	git_status_foreach(
      self.git_repository, file_status_callback, &fileStatusPayload);
}

@end
