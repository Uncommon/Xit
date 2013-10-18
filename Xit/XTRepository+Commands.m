#import "XTRepository+Commands.h"
#import "XTConstants.h"
#import <ObjectiveGit/ObjectiveGit.h>

@interface XTRepository ()
@property(readwrite) GTRepository *gtRepo;
@end

@implementation XTRepository (Commands)

- (BOOL)initializeRepository
{
  NSError *error = nil;

  if (![GTRepository initializeEmptyRepositoryAtFileURL:self.repoURL error:&error])
    return NO;
  GTRepository *gtRepo = [GTRepository repositoryWithURL:self.repoURL error:&error];
  _gtRepo = gtRepo;
  return _gtRepo != nil;
}

- (BOOL)saveStash:(NSString *)name
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"stash", @"save", name ]
                    writes:YES
                     error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)createBranch:(NSString *)name
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"checkout", @"-b", name ]
                    writes:YES
                     error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)deleteBranch:(NSString *)name error:(NSError *__autoreleasing *)error
{
  NSParameterAssert(error);
  *error = nil;

  return [self executeWritingBlock:^BOOL{
    NSString *fullBranch =
        [[GTBranch localNamePrefix] stringByAppendingString:name];
    GTBranch *branch =
        [GTBranch branchWithName:fullBranch repository:self.gtRepo error:error];

    if (*error != nil)
      return NO;
    [branch deleteWithError:error];
    return *error == nil;
  }];
}

- (NSString *)currentBranch
{
  if (cachedBranch == nil) {
    NSError *error = nil;
    GTBranch *branch = [self.gtRepo currentBranchWithError:&error];

    if (error != nil)
      return nil;

    NSString *remoteName = [branch remoteName];

    if (remoteName != nil)
      // shortName strips the remote name, so put it back
      cachedBranch =
          [NSString stringWithFormat:@"%@/%@", remoteName, [branch shortName]];
    else
      cachedBranch = [branch shortName];
  }
  return cachedBranch;
}

- (BOOL)merge:(NSString *)name error:(NSError **)error
{
  [self executeGitWithArgs:@[ @"merge", name ] writes:YES error:error];
  return *error == nil;
}

- (BOOL)push:(NSString *)remote
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"push", @"--all", @"--force", remote ]
                    writes:NO
                     error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)checkout:(NSString *)branch error:(NSError **)resultError
{
  return [self executeWritingBlock:^BOOL{
    cachedBranch = nil;
    cachedHeadRef = nil;
    cachedHeadSHA = nil;

    const GTCheckoutStrategyType strategy = GTCheckoutStrategySafeCreate;
    NSString *branchRef = [[GTBranch localNamePrefix]
        stringByAppendingPathComponent:branch];
    GTReference *ref = [GTReference
        referenceByLookingUpReferencedNamed:branchRef
                               inRepository:self.gtRepo
                                      error:resultError];

    if (ref != nil)
      return [self.gtRepo checkoutReference:ref
                              strategy:strategy
                                 error:resultError
                         progressBlock:NULL];

    if ([branch length] == 40) {
      if (resultError != NULL)
        *resultError = nil;

      GTCommit *commit = [self.gtRepo lookupObjectBySHA:branch objectType:GTObjectTypeCommit error:resultError];

      if (commit != nil)
        return [self.gtRepo checkoutCommit:commit
                      strategy:strategy
                         error:resultError
                 progressBlock:NULL];
    }
    return NO;
  }];
}

- (BOOL)createTag:(NSString *)name withMessage:(NSString *)msg
{
  return [self executeWritingBlock:^BOOL{
    NSError *error = nil;
    GTReference *headRef = [self.gtRepo headReferenceWithError:&error];
    GTSignature *signature = [self.gtRepo userSignatureForNow];

    if ((headRef == nil) || (signature == nil))
      return NO;

    [self.gtRepo createTagNamed:name
                    target:[headRef resolvedTarget]
                    tagger:[self.gtRepo userSignatureForNow]
                   message:msg
                     error:&error];
    return error == nil;
  }];
}

- (BOOL)deleteTag:(NSString *)name error:(NSError *__autoreleasing *)error
{
  return [self executeWritingBlock:^BOOL{
    int result = git_tag_delete([self.gtRepo git_repository], [name UTF8String]);

    if (result == 0)
      return YES;
    else {
      if (error != NULL)
        *error = [NSError git_errorFor:result];
      return NO;
    }
  }];
}

- (BOOL)addRemote:(NSString *)name withUrl:(NSString *)url
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"remote", @"add", name, url ]
                    writes:YES
                     error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)deleteRemote:(NSString *)name error:(NSError *__autoreleasing *)error
{
  return [self executeGitWithArgs:@[ @"remote", @"rm", name ]
                           writes:YES
                            error:error] != nil;
}

- (NSString *)diffForStagedFile:(NSString *)file
{
  NSData *output = [self executeGitWithArgs:@[
      @"diff-index", @"--patch", @"--cached", [self parentTree], @"--", file ]
                                     writes:NO
                                      error:nil];

  if (output == nil)
    return nil;
  return [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
}

- (NSString *)diffForUnstagedFile:(NSString *)file
{
  NSData *output =
      [self executeGitWithArgs:@[ @"diff-files", @"--patch", @"--", file ]
                        writes:NO
                         error:nil];

  if (output == nil)
    return nil;
  return [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
}

- (NSString *)diffForCommit:(NSString *)sha
{
  NSData *output = [self executeGitWithArgs:@[ @"diff-tree", @"--root", @"--cc",
                                               @"-C90%", @"-M90%", sha ]
                                     writes:NO
                                      error:NULL];

  return [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
}

- (BOOL)stagePatch:(NSString *)patch
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"apply", @"--cached" ]
                 withStdIn:patch
                    writes:YES
                     error:&error];
  return error == nil;
}

- (BOOL)unstagePatch:(NSString *)patch
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"apply", @"--cached", @"--reverse" ]
                 withStdIn:patch
                    writes:YES
                     error:&error];
  return error == nil;
}

- (BOOL)discardPatch:(NSString *)patch
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"apply", @"--reverse" ]
                 withStdIn:patch
                    writes:YES
                     error:&error];
  return error == nil;
}

- (BOOL)renameBranch:(NSString *)branch to:(NSString *)newName
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"branch", @"-m", branch, newName ]
                    writes:YES
                     error:&error];
  return error == nil;
}

- (BOOL)renameTag:(NSString *)branch to:(NSString *)newName
{
  // TODO: delete and re-make the tag
  // not doable for signed tags?
  return NO;
}

- (BOOL)renameRemote:(NSString *)branch to:(NSString *)newName
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"remote", @"rename", branch, newName ]
                    writes:YES
                     error:&error];
  return error == nil;
}

- (BOOL)popStash:(NSString *)name error:(NSError **)error
{
  NSError *localError = nil;

  name = [name componentsSeparatedByString:@" "][0];
  if (![self executeGitWithArgs:@[ @"stash", @"pop", name ]
                         writes:YES
                          error:&localError]) {
    if (([localError code] == 1) &&
        [[localError domain] isEqualToString:XTErrorDomainGit])
      return YES;  // pop may return 1 on success
    if (error != NULL)
      *error = localError;
    return NO;
  }
  return YES;
}

- (BOOL)applyStash:(NSString *)name error:(NSError **)error
{
  NSError *localError = nil;

  name = [name componentsSeparatedByString:@" "][0];
  if (![self executeGitWithArgs:@[ @"stash", @"apply", name ]
                         writes:YES
                          error:&localError]) {
    if (([localError code] == 1) &&
        [[localError domain] isEqualToString:XTErrorDomainGit])
      return YES;  // apply may return 1 on success
    if (error != NULL)
      *error = localError;
    return NO;
  }
  return YES;
}

- (BOOL)dropStash:(NSString *)name error:(NSError **)error
{
  name = [name componentsSeparatedByString:@" "][0];
  return [self executeGitWithArgs:@[ @"stash", @"drop", name ]
                           writes:YES
                            error:error];
}

- (BOOL)addSubmoduleAtPath:(NSString *)path
                 urlOrPath:(NSString *)urlOrPath
                     error:(NSError **)error
{
  return [self executeGitWithArgs:@[ @"submodule", @"add", @"-f",
                                     urlOrPath, path ]
                         writes:YES
                          error:error];
/* The clone step must be implemented for this to be good.
  return [self executeWritingBlock:^BOOL{
    git_submodule *gitSub = NULL;
    int result = git_submodule_add_setup(
        &gitSub, [self.gtRepo git_repository],
        [urlOrPath UTF8String], [path UTF8String], false);

    if ((result != 0) && (error != NULL)) {
      *error = [NSError git_errorFor:result];
      return NO;
    }
    // clone the sub-repo
    git_submodule_add_finalize(gitSub);
    return YES;
  }];
*/
}

@end
