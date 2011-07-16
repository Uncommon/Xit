//
//  GITBasic+Xit.m
//  Xit
//
//  Created by glaullon on 7/15/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import "GITBasic+Xit.h"


@implementation Xit (GITBasic_Xit)


-(bool)initRepo
{
    bool res=false;
    
    NSTask* task = [self createTaskWithArgs:[NSArray arrayWithObject:@"init"]];
    
	NSPipe* pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
    
    [task  launch];
    [task waitUntilExit];
    int status = [task terminationStatus];
    
    if (status == 0)
        res=true;
    else
        NSLog(@"Task failed.");
    
    return res;
}

-(bool)createBranch:(NSString *)name
{
    bool res=NO;
    
    NSTask* task = [self createTaskWithArgs:[NSArray arrayWithObjects:@"checkout",@"-b",name,nil]];
    
	NSPipe* pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
    
    [task  launch];
    [task waitUntilExit];
    int status = [task terminationStatus];
    
    NSData *output = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *string = [[[NSString alloc] initWithData: output encoding: NSUTF8StringEncoding] autorelease];
    
    NSLog(@"\nstatus=%d\n%@\n", status,string);
    
    if (status == 0){
        res=YES;
    }
    
    return res;
}

-(bool)addFile:(NSString *)file
{
    bool res=NO;
    
    NSTask* task = [self createTaskWithArgs:[NSArray arrayWithObjects:@"add",file,nil]];
    
	NSPipe* pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
    
    [task  launch];
    [task waitUntilExit];
    int status = [task terminationStatus];
    
    NSData *output = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *string = [[[NSString alloc] initWithData: output encoding: NSUTF8StringEncoding] autorelease];
    
    NSLog(@"\nstatus=%d\n%@\n", status,string);
    
    if (status == 0){
        res=YES;
    }
    
    return res;
}

-(bool)commitWithMessage:(NSString *)message
{
    bool res=NO;
    
    NSTask* task = [self createTaskWithArgs:[NSArray arrayWithObjects:@"commit",@"-m",message,nil]];
    
	NSPipe* pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
    
    [task  launch];
    [task waitUntilExit];
    int status = [task terminationStatus];
    
    NSData *output = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *string = [[[NSString alloc] initWithData: output encoding: NSUTF8StringEncoding] autorelease];
    
    NSLog(@"\nstatus=%d\n%@\n", status,string);
    
    if (status == 0){
        res=YES;
    }
    
    return res;
}

@end
