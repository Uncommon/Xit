#import "XTRepository+Parsing.h"
#import "NSDate+Extensions.h"
#import <ObjectiveGit/ObjectiveGit.h>
#import "GTRepository+Xit.h"

NSString *XTHeaderNameKey = @"name";
NSString *XTHeaderContentKey = @"content";

@implementation XTRepository (Reading)

- (BOOL)
    readRefsWithLocalBlock:(void (^)(NSString *name, NSString *commit))localBlock
               remoteBlock:(void (^)(NSString *remoteName, NSString *branchName,
                                     NSString *commit))remoteBlock
                  tagBlock:(void (^)(NSString *name, NSString *commit))tagBlock
{
  NSError *error = nil;
  NSData *output =
      [self executeGitWithArgs:@[ @"show-ref", @"-d" ]
                        writes:NO
                         error:&error];

  if (output != nil) {
    NSString *refs =
        [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    NSScanner *scanner = [NSScanner scannerWithString:refs];
    NSString *localBranchPrefix = @"refs/heads/";
    NSString *tagPrefix = @"refs/tags/";
    NSString *remotePrefix = @"refs/remotes/";
    NSString *commit;
    NSString *name;

    while ([scanner scanUpToString:@" " intoString:&commit]) {
      [scanner scanUpToString:@"\n" intoString:&name];
      if ([name hasPrefix:localBranchPrefix]) {
        localBlock([name substringFromIndex:[localBranchPrefix length]],
                   commit);
      } else if ([name hasPrefix:tagPrefix]) {
        tagBlock([name substringFromIndex:[tagPrefix length]], commit);
      } else if ([name hasPrefix:remotePrefix]) {
        NSString *remoteName = [name pathComponents][2];
        const NSUInteger prefixLen =
            [remotePrefix length] + [remoteName length] + 1;
        NSString *branchName = [name substringFromIndex:prefixLen];

        remoteBlock(remoteName, branchName, commit);
      }
    }
  }
  return error == nil;
}

- (BOOL)readStagedFilesWithBlock:(void (^)(NSString *, NSString *))block
{
  NSError *error = nil;
  GTIndex *index = [gtRepo indexWithError:&error];

  if (error != nil)
    return NO;
  for (GTIndexEntry *entry in index.entries) {
    NSString *status = @"";

    switch (entry.status) {
      case GTIndexEntryStatusUpdated:    status = @"M"; break;
      case GTIndexEntryStatusConflicted: status = @"C"; break;
      case GTIndexEntryStatusAdded:      status = @"A"; break;
      case GTIndexEntryStatusRemoved:    status = @"D"; break;
      case GTIndexEntryStatusUpToDate:   status = @""; break;
    }
    block(entry.path, status);
  }
  return YES;
}

- (BOOL)readUnstagedFilesWithBlock:(void (^)(NSString *, NSString *))block
{
  // TODO: use enum for status
  [self.gtRepo enumerateRelativeFileStatusUsingBlock:^(NSString *path, GTRepositoryFileStatus status, BOOL *stop) {
    NSString *statusString = @"";

    switch (status) {
      case GTRepositoryFileStatusWorkingTreeDeleted:
        statusString = @"D";
        break;
      case GTRepositoryFileStatusWorkingTreeModified:
        statusString = @"M";
        break;
      case GTRepositoryFileStatusWorkingTreeNew:
        statusString = @"A";
        break;
      default:
        return;
    }

    block(path, statusString);
  }];
  return YES;
}

- (BOOL)readStashesWithBlock:(void (^)(NSString *, NSString *))block
{
  NSError *error = nil;
  NSData *output =
      [self executeGitWithArgs:@[ @"stash", @"list", @"--pretty=%H %gd %gs" ]
                        writes:NO
                         error:&error];

  if (output != nil) {
    NSString *refs =
        [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    NSScanner *scanner = [NSScanner scannerWithString:refs];
    NSString *commit, *name;

    while ([scanner scanUpToString:@" " intoString:&commit]) {
      [scanner scanUpToString:@"\n" intoString:&name];
      block(commit, name);
    }
  }
  return error == nil;
}

- (BOOL)readSubmodulesWithBlock:(void (^)(GTSubmodule *sub))block
{
  [gtRepo enumerateSubmodulesRecursively:NO
                              usingBlock:^(GTSubmodule *sub, BOOL *stop){
    block(sub);
  }];
  return YES;
}

- (NSArray *)fileNamesForRef:(NSString *)ref
{
  GTCommit *commit = [self commitForRef:ref];

  if (commit == nil)
    return nil;

  GTTree *tree = commit.tree;
  NSMutableArray *result = [NSMutableArray array];
  NSError *error = nil;

  [tree enumerateContentsWithOptions:GTTreeEnumerationOptionPre
                               error:&error
                               block:^int(NSString *root, GTTreeEntry *entry) {
      if (git_tree_entry_type(entry.git_tree_entry) != GIT_OBJ_TREE)
        [result addObject:[root stringByAppendingPathComponent:entry.name]];
      return 0;
  }];
  return result;
}

NSString *kHeaderFormat = @"--format="
                           "%H%n%T%n%P%n"     // commit, tree, and parent hashes
                           "%d%n"             // ref names
                           "%an%n%ae%n%aD%n"  // author name, email, date
                           "%cn%n%ce%n%cD"    // committer name, email, date
                           "%x00%B%x00";      // message

NSString *XTCommitSHAKey = @"sha",
         *XTTreeSHAKey = @"tree",
         *XTParentSHAsKey = @"parents",
         *XTRefsKey = @"refs",
         *XTAuthorNameKey = @"authorname",
         *XTAuthorEmailKey = @"authoremail",
         *XTAuthorDateKey = @"authordate",
         *XTCommitterNameKey = @"committername",
         *XTCommitterEmailKey = @"committeremail",
         *XTCommitterDateKey = @"committerdate";

- (void)parseDateInArray:(NSMutableArray *)array atIndex:(NSUInteger)index
{
  NSDate *date = [NSDate dateFromRFC2822:array[index]];

  [array removeObjectAtIndex:index];
  [array insertObject:date atIndex:index];
}

- (GTCommit*)commitForRef:(NSString*)ref
{
  NSError *error;
  GTObject *object = [gtRepo lookupObjectByRefspec:ref error:&error];

  if (object == nil)
    return nil;

  return [gtRepo lookupObjectByOID:object.OID
                        objectType:GTObjectTypeCommit
                             error:&error];
}

- (BOOL)parseCommit:(NSString *)ref
         intoHeader:(NSDictionary **)header
            message:(NSString **)message
              files:(NSArray **)files
{
  NSAssert(header != NULL, @"NULL header");
  NSAssert(message != NULL, @"NULL message");
  NSAssert(files != NULL, @"NULL files");

  NSError *error = nil;
  NSData *output = [self executeGitWithArgs:@[ @"show", @"-z", @"--summary",
                                               @"--name-only", kHeaderFormat,
                                               ref ]
                                     writes:NO
                                      error:&error];

  if (error != nil)
    return NO;

  NSString *commit =
      [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
  NSArray *sections = [commit componentsSeparatedByString:@"\0"];

  if ([sections count] < 2) {
    NSLog(@"Commit failed to parse: %@", commit);
    return NO;
  }

  NSMutableArray *headerLines =
      [[sections[0] componentsSeparatedByString:@"\n"] mutableCopy];
  NSString *lastLine = [headerLines lastObject];

  if ([lastLine length] == 0)
    [headerLines removeObject:lastLine];

  NSArray *headerKeys =
      @[ XTCommitSHAKey, XTTreeSHAKey, XTParentSHAsKey, XTRefsKey,
         XTAuthorNameKey, XTAuthorEmailKey, XTAuthorDateKey, XTCommitterNameKey,
         XTCommitterEmailKey, XTCommitterDateKey ];

  // Convert refs from a string to a set
  const NSUInteger refsLineIndex = [headerKeys indexOfObject:XTRefsKey];
  NSString *refsLine = headerLines[refsLineIndex];
  NSSet *refsSet = nil;

  refsLine = [refsLine stringByTrimmingCharactersInSet:
          [NSCharacterSet characterSetWithCharactersInString:@" ()"]];

  [headerLines removeObjectAtIndex:refsLineIndex];
  if ([refsLine length] == 0)
    refsSet = [NSSet set];
  else
    refsSet = [NSSet setWithArray:[refsLine componentsSeparatedByString:@", "]];
  [headerLines insertObject:refsSet atIndex:refsLineIndex];

  // Convert dates to NSDate objects
  [self parseDateInArray:headerLines
                 atIndex:[headerKeys indexOfObject:XTAuthorDateKey]];
  [self parseDateInArray:headerLines
                 atIndex:[headerKeys indexOfObject:XTCommitterDateKey]];

  // Convert parents into an array
  const NSUInteger parentsLineIndex =
      [headerKeys indexOfObject:XTParentSHAsKey];
  NSString *parentsString = headerLines[parentsLineIndex];
  NSArray *parents = [parentsString componentsSeparatedByCharactersInSet:
          [NSCharacterSet whitespaceCharacterSet]];

  [headerLines removeObjectAtIndex:parentsLineIndex];
  [headerLines insertObject:parents atIndex:parentsLineIndex];

  // Set the output variables
  NSAssert([headerLines count] == [headerKeys count], @"bad header line count");
  *header = [NSMutableDictionary dictionaryWithObjects:headerLines
                                               forKeys:headerKeys];
  *message = sections[1];
  *files = [sections subarrayWithRange:NSMakeRange(2, [sections count] - 2)];

  // The first file line has newlines at the beginning.
  NSMutableArray *mutableFiles = [*files mutableCopy];

  if ([mutableFiles count] > 0) {
    while (([mutableFiles count] > 0) && ([mutableFiles[0] length] == 0))
      [mutableFiles removeObjectAtIndex:0];

    if ([mutableFiles count] > 0) {
      NSString *firstLine = [mutableFiles[0] stringByTrimmingCharactersInSet:
          [NSCharacterSet whitespaceAndNewlineCharacterSet]];

      [mutableFiles setObject:firstLine atIndexedSubscript:0];
    }
  }

  // Filter out any blank lines.
  NSPredicate *predicate =
      [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
    return [obj length] > 0;
  }];

  *files = [mutableFiles filteredArrayUsingPredicate:predicate];

  return YES;
}

- (BOOL)stageFile:(NSString *)file
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"add", file ] writes:YES error:&error];
  return error == nil;
}

- (BOOL)unstageFile:(NSString *)file
{
  NSArray *args;
  NSError *error = nil;

  if (![self hasHeadReference])
    args = @[ @"rm", @"--cached", file ];
  else
    args = @[ @"reset", @"-q", @"HEAD", file ];
  [self executeGitWithArgs:args writes:YES error:&error];
  return error == nil;
}

- (BOOL)commitWithMessage:(NSString *)message
                    amend:(BOOL)amend
              outputBlock:(void (^)(NSString *output))outputBlock
                    error:(NSError **)error
{
  NSArray *args = @[ @"commit", @"-F", @"-" ];

  if (amend)
    args = [args arrayByAddingObject:@"--amend"];

  NSData *output = [self executeGitWithArgs:args
                                  withStdIn:message
                                     writes:YES
                                      error:error];

  if (output == nil)
    return NO;
  if (outputBlock != NULL)
    outputBlock([[NSString alloc] initWithData:output
                                      encoding:NSUTF8StringEncoding]);
  return YES;
}

@end
