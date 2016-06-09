#import "XTRepository+Commands.h"
#import "XTConstants.h"
#import <ObjectiveGit/ObjectiveGit.h>

@implementation XTRepository (Commands)

- (BOOL)initializeRepository
{
  NSError *error = nil;
  GTRepository *newRepo = [GTRepository
      initializeEmptyRepositoryAtFileURL:_repoURL
                                 options:nil
                                   error:&error];
  
  if ((newRepo == nil) || (error != nil))
    return NO;
  _gtRepo = newRepo;
  return YES;
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
    GTReference *ref = [_gtRepo lookUpReferenceWithName:fullBranch error:error];
    GTBranch *branch = [GTBranch branchWithReference:ref repository:_gtRepo];

    if (*error != nil)
      return NO;
    [branch deleteWithError:error];
    return *error == nil;
  }];
}

- (NSString *)currentBranch
{
  if (_cachedBranch == nil) {
    NSError *error = nil;
    GTBranch *branch = [_gtRepo currentBranchWithError:&error];

    if (error != nil)
      return nil;

    NSString *remoteName = branch.remoteName;

    if (remoteName != nil)
      // shortName strips the remote name, so put it back
      _cachedBranch =
          [NSString stringWithFormat:@"%@/%@", remoteName, branch.shortName];
    else
      _cachedBranch = branch.shortName;
  }
  return _cachedBranch;
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
    _cachedBranch = nil;
    _cachedHeadRef = nil;
    _cachedHeadSHA = nil;

    const GTCheckoutStrategyType strategy = GTCheckoutStrategySafe;
    NSString *branchRef = [[GTBranch localNamePrefix]
        stringByAppendingPathComponent:branch];
    GTReference *ref = [_gtRepo lookUpReferenceWithName:branchRef error:resultError];

    if (ref != nil)
      return [_gtRepo checkoutReference:ref
                              strategy:strategy
                                 error:resultError
                         progressBlock:NULL];

    if (branch.length == 40) {
      if (resultError != NULL)
        *resultError = nil;

      GTCommit *commit = [_gtRepo
          lookUpObjectBySHA:branch
          objectType:GTObjectTypeCommit
          error:resultError];

      if (commit != nil)
        return [_gtRepo checkoutCommit:commit
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
    GTReference *headRef = [_gtRepo headReferenceWithError:&error];
    GTSignature *signature = [_gtRepo userSignatureForNow];

    if ((headRef == nil) || (signature == nil))
      return NO;

    [_gtRepo createTagNamed:name
                     target:headRef.resolvedTarget
                     tagger:[_gtRepo userSignatureForNow]
                    message:msg
                      error:&error];
    return error == nil;
  }];
}

- (BOOL)deleteTag:(NSString *)name error:(NSError *__autoreleasing *)error
{
  return [self executeWritingBlock:^BOOL{
    int result = git_tag_delete([_gtRepo git_repository], name.UTF8String);

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

- (NSString *)urlStringForRemote:(NSString *)remoteName
{
  NSString *remoteURL =
      [[_gtRepo configurationWithError:nil] stringForKey:remoteName];
  
  return remoteURL;
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

- (BOOL)unstageAllFiles
{
  // "Unstaging" just means making things match what's in the head commit,
  // so if we're unstaging everything we can just copy the tree over.
  NSError *error = nil;
  GTReference *headRef = [_gtRepo headReferenceWithError:&error];
  GTCommit *headCommit = (GTCommit*)headRef.resolvedTarget;
  
  if ((headCommit == nil) || ![headCommit isKindOfClass:[GTCommit class]])
    return NO;
  
  GTIndex *index = [_gtRepo indexWithError:&error];
  
  if (index == nil)
    return NO;
  
  if (![index addContentsOfTree:headCommit.tree error:&error]) {
    NSLog(@"couldn't unstage all: %@", error);
    return NO;
  }
  if (![index write:&error]) {
    NSLog(@"couldn't write index: %@", error);
    return NO;
  }
  return YES;
}

- (BOOL)renameBranch:(NSString *)branch to:(NSString *)newName
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"branch", @"-m", branch, newName ]
                    writes:YES
                     error:&error];
  return error == nil;
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
    if ((localError.code == 1) &&
        [localError.domain isEqualToString:XTErrorDomainGit])
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
    if ((localError.code == 1) &&
        [localError.domain isEqualToString:XTErrorDomainGit])
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
                            error:error] != nil;
}

- (BOOL)addSubmoduleAtPath:(NSString *)path
                 urlOrPath:(NSString *)urlOrPath
                     error:(NSError **)error
{
  return [self executeGitWithArgs:@[ @"submodule", @"add", @"-f",
                                     urlOrPath, path ]
                           writes:YES
                            error:error] != nil;
/* The clone step must be implemented for this to be good.
  return [self executeWritingBlock:^BOOL{
    git_submodule *gitSub = NULL;
    int result = git_submodule_add_setup(
        &gitSub, [gtRepo git_repository],
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
