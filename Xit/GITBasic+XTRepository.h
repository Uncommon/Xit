//
//  GITBasic+Xit.h
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import <Foundation/Foundation.h>
#import "XTRepository.h"

@interface XTRepository (GITBasic_XTRepository)

- (bool)initializeRepository;
- (bool)createBranch:(NSString *)name;
- (NSString *)currentBranch;
- (bool)addFile:(NSString *)file;
- (bool)commitWithMessage:(NSString *)message;
- (bool)createTag:(NSString *)name withMessage:(NSString *)msg;
- (bool)addRemote:(NSString *)name withUrl:(NSString *)url;
- (bool)push:(NSString *)remote;
- (bool)checkout:(NSString *)branch;
- (bool)stash:(NSString *)name;
- (bool)merge:(NSString *)name;

@end
