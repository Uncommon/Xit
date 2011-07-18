//
//  GITBasic+Xit.m
//  Xit
//
//  Created by glaullon on 7/15/11.
//

#import "GITBasic+Xit.h"


@implementation Xit (GITBasic_Xit)


-(bool)initRepo
{
    NSError *error = nil;
    bool res=false;
    
    [self exectuteGitWithArgs:[NSArray arrayWithObject:@"init"] error:&error];
    
    if (error == nil)
        res=true;
    else
        NSLog(@"Task failed.");
    
    return res;
}

-(bool)createBranch:(NSString *)name
{
    NSError *error = nil;
    bool res=NO;
    
    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"checkout",@"-b",name,nil] error:&error];
    
    if (error == nil){
        res=YES;
    }
    
    return res;
}

-(bool)addFile:(NSString *)file
{
    NSError *error = nil;
    bool res=NO;
    
    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"add",file,nil] error:&error];

    if (error == nil){
        res=YES;
    }
    
    return res;
}

-(bool)commitWithMessage:(NSString *)message
{
    NSError *error = nil;
    bool res=NO;
    
    [self exectuteGitWithArgs:[NSArray arrayWithObjects:@"commit",@"-m",message,nil] error:&error];
    
    if (error == nil){
        res=YES;
    }
    
    return res;
}

@end
