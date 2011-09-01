//
//  GITBasic+Xit.m
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import "GITBasic+XTRepository.h"


@implementation XTRepository (GITBasic_XTRepository)


- (bool)initRepo {
    NSError *error = nil;
    bool res = false;

    [self exectuteGitWithArgs:[NSArray arrayWithObject:@"init"] error:&error];

    if (error == nil)
        res = true;

    return res;
}

- (bool)stash:(NSString *)name {
    NSError *error = nil;
    bool res = NO;

    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"stash", @"save", name, nil] error:&error];

    if (error == nil) {
        res = YES;
    }

    return res;
}

- (bool)createBranch:(NSString *)name {
    NSError *error = nil;
    bool res = NO;

    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"checkout", @"-b", name, nil] error:&error];

    if (error == nil) {
        res = YES;
    }

    return res;
}

- (bool)merge:(NSString *)name {
    NSError *error = nil;
    bool res = NO;

    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"merge", @"--no-ff", name, nil] error:&error];

    if (error == nil) {
        res = YES;
    }

    return res;
}

- (bool)push:(NSString *)remote {
    NSError *error = nil;
    bool res = NO;

    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"push", @"--all", @"--force", remote, nil] error:&error];

    if (error == nil) {
        res = YES;
    }

    return res;
}

- (bool)checkout:(NSString *)branch {
    NSError *error = nil;
    bool res = NO;

    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"checkout", branch, nil] error:&error];

    if (error == nil) {
        res = YES;
    }

    return res;
}

- (bool)createTag:(NSString *)name withMessage:(NSString *)msg {
    NSError *error = nil;
    bool res = NO;

    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"tag", @"-a", name, @"-m", msg, nil] error:&error];

    if (error == nil) {
        res = YES;
    }

    return res;
}

- (bool)AddRemote:(NSString *)name withUrl:(NSString *)url {
    NSError *error = nil;
    bool res = NO;

    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"remote", @"add", name, url, nil] error:&error];

    if (error == nil) {
        res = YES;
    }

    return res;
}

- (bool)addFile:(NSString *)file {
    NSError *error = nil;
    bool res = NO;

    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"add", file, nil] error:&error];

    if (error == nil) {
        res = YES;
    }

    return res;
}

- (bool)commitWithMessage:(NSString *)message {
    NSError *error = nil;
    bool res = NO;

    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"commit", @"-m", message, nil] error:&error];

    if (error == nil) {
        res = YES;
    }

    return res;
}

@end
