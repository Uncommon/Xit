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

@end
