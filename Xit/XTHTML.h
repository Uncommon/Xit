#import <Foundation/Foundation.h>

@interface XTHTML : NSObject

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
