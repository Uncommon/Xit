//
//  GITBasic+Xit.h
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import <Foundation/Foundation.h>
#import "Xit.h"

@interface Xit (GITBasic_Xit)

-(bool)initRepo;
-(bool)createBranch:(NSString *)name;
-(bool)addFile:(NSString *)file;
-(bool)commitWithMessage:(NSString *)message;
-(bool)createTag:(NSString *)name withMessage:(NSString *)msg;
-(bool)AddRemote:(NSString *)name withUrl:(NSString *)url;
-(bool)push:(NSString *)remote;
-(bool)checkout:(NSString *)branch;
-(bool)stash:(NSString *)name;

@end
