//
//  XTRepository+Parsing.m
//  Xit
//
//  Created by David Catmull on 7/13/12.
//

#import "XTRepository+Parsing.h"
#import "NSDate+Extensions.h"


NSString *XTHeaderNameKey = @"name";
NSString *XTHeaderContentKey = @"content";

@implementation XTRepository (Reading)

- (BOOL)readRefsWithLocalBlock:(void (^)(NSString *name, NSString *commit))localBlock
                   remoteBlock:(void (^)(NSString *remoteName, NSString *branchName, NSString *commit))remoteBlock
                      tagBlock:(void (^)(NSString *name, NSString *commit))tagBlock {
    NSError *error = nil;
    NSData *output = [self executeGitWithArgs:[NSArray arrayWithObjects:@"show-ref", @"-d", nil] error:&error];

    if (output != nil) {
        NSString *refs = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        NSScanner *scan = [NSScanner scannerWithString:refs];
        NSString *commit;
        NSString *name;

        while ([scan scanUpToString:@" " intoString:&commit]) {
            [scan scanUpToString:@"\n" intoString:&name];
            if ([name hasPrefix:@"refs/heads/"]) {
                localBlock([name lastPathComponent], commit);
            } else if ([name hasPrefix:@"refs/tags/"]) {
                tagBlock([name lastPathComponent], commit);
            } else if ([name hasPrefix:@"refs/remotes/"]) {
                NSString *remoteName = [[name pathComponents] objectAtIndex:2];
                NSString *branchName = [name lastPathComponent];

                remoteBlock(remoteName, branchName, commit);
            }
        }
    }
    return error == nil;
}

- (BOOL)readStagedFilesWithBlock:(void (^)(NSString *, NSString *))block {
    NSError *error = nil;
    NSData *output = [self executeGitWithArgs:[NSArray arrayWithObjects:@"diff-index", @"--cached", [self parentTree], nil] error:&error];

    if ((output == nil) || (error != nil))
        return NO;

    NSString *filesStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    filesStr = [filesStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *files = [filesStr componentsSeparatedByString:@"\n"];

    for (NSString *file in files) {
        NSArray *info = [file componentsSeparatedByString:@"\t"];
        if (info.count > 1) {
            NSString *name = [info lastObject];
            NSString *status = [[[info objectAtIndex:0] componentsSeparatedByString:@" "] lastObject];
            status = [status substringToIndex:1];
            block(name, status);
        }
    }
    return YES;
}

- (BOOL)readUnstagedFilesWithBlock:(void (^)(NSString *, NSString *))block {
    NSError *error = nil;
    NSData *output = [self executeGitWithArgs:[NSArray arrayWithObjects:@"diff-files", nil] error:nil];

    if (error != nil)
        return NO;

    NSString *filesStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    filesStr = [filesStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *files = [filesStr componentsSeparatedByString:@"\n"];

    [files enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
        NSString *file = (NSString *)obj;
        NSArray *info = [file componentsSeparatedByString:@"\t"];

        if (info.count > 1) {
            NSString *name = [info lastObject];
            NSString *status = [[[info objectAtIndex:0] componentsSeparatedByString:@" "] lastObject];

            status = [status substringToIndex:1];
            block(name, status);
        }
    }];

    output = [self executeGitWithArgs:[NSArray arrayWithObjects:@"ls-files", @"--others", @"--exclude-standard", nil] error:nil];
    filesStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    filesStr = [filesStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    files = [filesStr componentsSeparatedByString:@"\n"];
    [files enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
        NSString *file = (NSString *)obj;

        if (file.length > 0)
            block(file, @"?");
    }];
    return YES;
}

- (BOOL)readStashesWithBlock:(void (^)(NSString *, NSString *))block {
    NSError *error = nil;
    NSData *output = [self executeGitWithArgs:[NSArray arrayWithObjects:@"stash", @"list", @"--pretty=%H %gd %gs", nil] error:&error];

    if (output != nil) {
        NSString *refs = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        NSScanner *scanner = [NSScanner scannerWithString:refs];
        NSString *commit, *name;

        while ([scanner scanUpToString:@" " intoString:&commit]) {
            [scanner scanUpToString:@"\n" intoString:&name];
            block(commit, name);
        }
    }
    return error == nil;
}

- (NSArray *)fileNamesForRef:(NSString *)ref {
    NSError *error = nil;
    NSData *output = [self executeGitWithArgs:[NSArray arrayWithObjects:@"ls-tree", @"--name-only", @"-r", ref, nil] error:nil];

    if (error != nil)
        return nil;

    NSString *ls = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];

    ls = [ls stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [ls componentsSeparatedByString:@"\n"];
}

NSString *kHeaderFormat = @"--format="
        "%H%n%T%n%P%n"      // commit, tree, and parent hashes
        "%d%n"              // ref names
        "%an%n%ae%n%aD%n"   // author name, email, date
        "%cn%n%ce%n%cD"     // committer name, email, date
        "%x00%B%x00";       // message

NSString
        *XTCommitSHAKey = @"sha",
        *XTTreeSHAKey = @"tree",
        *XTParentSHAsKey = @"parents",
        *XTRefsKey = @"refs",
        *XTAuthorNameKey = @"authorname",
        *XTAuthorEmailKey = @"authoremail",
        *XTAuthorDateKey = @"authordate",
        *XTCommitterNameKey = @"committername",
        *XTCommitterEmailKey = @"committeremail",
        *XTCommitterDateKey = @"committerdate";

- (void)parseDateInArray:(NSMutableArray *)array atIndex:(NSUInteger)index {
    NSDate *date = [NSDate dateFromRFC2822:[array objectAtIndex:index]];

    [array removeObjectAtIndex:index];
    [array insertObject:date atIndex:index];
}

- (BOOL)parseCommit:(NSString *)ref intoHeader:(NSDictionary **)header message:(NSString **)message files:(NSArray **)files {
    NSAssert(header != NULL, @"NULL header");
    NSAssert(message != NULL, @"NULL message");
    NSAssert(files != NULL, @"NULL files");

    NSError *error = nil;
    NSData *output = [self executeGitWithArgs:[NSArray arrayWithObjects:@"show", @"-z", @"--summary", @"--name-only", kHeaderFormat, ref, nil] error:&error];

    if (error != nil)
        return NO;

    NSString *commit = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    NSArray *sections = [commit componentsSeparatedByString:@"\0"];

    if ([sections count] < 2) {
        NSLog(@"Commit failed to parse: %@", commit);
        return NO;
    }

    NSMutableArray *headerLines = [[[sections objectAtIndex:0] componentsSeparatedByString:@"\n"] mutableCopy];
    NSString *lastLine = [headerLines lastObject];

    if ([lastLine length] == 0)
        [headerLines removeObject:lastLine];

    NSArray *headerKeys = [NSArray arrayWithObjects:
            XTCommitSHAKey,
            XTTreeSHAKey,
            XTParentSHAsKey,
            XTRefsKey,
            XTAuthorNameKey,
            XTAuthorEmailKey,
            XTAuthorDateKey,
            XTCommitterNameKey,
            XTCommitterEmailKey,
            XTCommitterDateKey,
            nil];

    // Convert refs from a string to a set
    const NSUInteger refsLineIndex = [headerKeys indexOfObject:XTRefsKey];
    NSString *refsLine = [headerLines objectAtIndex:refsLineIndex];
    NSSet *refsSet = nil;

    refsLine = [refsLine stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ()"]];

    [headerLines removeObjectAtIndex:refsLineIndex];
    if ([refsLine length] == 0)
        refsSet = [NSSet set];
    else
        refsSet = [NSSet setWithArray:[refsLine componentsSeparatedByString:@", "]];
    [headerLines insertObject:refsSet atIndex:refsLineIndex];

    // Convert dates to NSDate objects
    [self parseDateInArray:headerLines atIndex:[headerKeys indexOfObject:XTAuthorDateKey]];
    [self parseDateInArray:headerLines atIndex:[headerKeys indexOfObject:XTCommitterDateKey]];

    // Convert parents into an array
    const NSUInteger parentsLineIndex = [headerKeys indexOfObject:XTParentSHAsKey];
    NSString *parentsString = [headerLines objectAtIndex:parentsLineIndex];
    NSArray *parents = [parentsString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    [headerLines removeObjectAtIndex:parentsLineIndex];
    [headerLines insertObject:parents atIndex:parentsLineIndex];

    // Set the output variables
    NSAssert([headerLines count] == [headerKeys count], @"bad header line count");
    *header = [NSMutableDictionary dictionaryWithObjects:headerLines forKeys:headerKeys];
    *message = [sections objectAtIndex:1];
    *files = [sections subarrayWithRange:NSMakeRange(2, [sections count]-2)];

    // The first file line has newlines at the beginning.
    NSMutableArray *mutableFiles = [*files mutableCopy];
    NSString *firstLine = [[mutableFiles objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    [mutableFiles removeObjectAtIndex:0];
    [mutableFiles insertObject:firstLine atIndex:0];

    // Filter out any blank lines.
    *files = [mutableFiles filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
        return [obj length] > 0;
    }]];

    return YES;
}

- (BOOL)stageFile:(NSString *)file {
    NSError *error = nil;

    [self executeGitWithArgs:[NSArray arrayWithObjects:@"add", file, nil] error:&error];
    return error == nil;
}

- (BOOL)unstageFile:(NSString *)file {
    NSArray *args;
    NSError *error = nil;

    if ([self parseReference:@"HEAD"] == nil)
        args = [NSArray arrayWithObjects:@"rm", @"--cached", file, nil];
    else
        args = [NSArray arrayWithObjects:@"reset", @"HEAD", file, nil];
    [self executeGitWithArgs:args error:&error];
    return error == nil;
}

- (BOOL)commitWithMessage:(NSString *)message amend:(BOOL)amend outputBlock:(void (^)(NSString *output))outputBlock error:(NSError **)error {
    NSArray *args = [NSArray arrayWithObjects:@"commit", @"-F", @"-", nil];

    if (amend)
        args = [args arrayByAddingObject:@"--amend"];

    NSData *output = [self executeGitWithArgs:args withStdIn:message error:error];

    if (output == nil)
        return NO;
    if (outputBlock != NULL)
        outputBlock([[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding]);
    return YES;
}

@end
