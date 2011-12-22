//
//  XTHTML.h
//  Xit
//
//  Created by VMware Inc. on 8/11/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XTHTML : NSObject

+ (NSString *)parseBlame:(NSString *)string;
+ (NSString *)parseDiff:(NSString *)diff;
+ (NSString *)escapeHTML:(NSString *)txt;
+ (NSString *)parseDiffBlock:(NSString *)txt;
+ (NSString *)parseDiffHeader:(NSString *)txt;
+ (NSString *)getFileName:(NSString *)line;
+ (NSString *)parseDiffChunk:(NSString *)txt;
+ (NSString *)parseBinaryDiff:(NSString *)txt;
+ (BOOL)isImage:(NSString *)file;
+ (NSString *)mimeTypeForFileName:(NSString *)name;
+ (NSArray *)getFilesNames:(NSString *)line;

@end
