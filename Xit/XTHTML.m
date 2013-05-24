#import "XTHTML.h"

@implementation XTHTML

+ (NSString *)parseDiff:(NSString *)txt {
    txt = [XTHTML escapeHTML:txt];

    NSMutableString *res = [NSMutableString string];
    NSScanner *scan = [NSScanner scannerWithString:txt];
    NSString *block;

    if (![txt hasPrefix:@"diff --"])
        [scan scanUpToString:@"diff --" intoString:&block];  // move to first diff

    while ([scan scanString:@"diff --" intoString:NULL]) { // is a diff start?
        [scan scanUpToString:@"\ndiff --" intoString:&block];
        [res appendString:[self parseDiffBlock:[NSString stringWithFormat:@"diff --%@", block]]];
    }

    return res;
}


+ (NSString *)parseDiffBlock:(NSString *)txt {
    NSMutableString *res = [NSMutableString string];
    NSScanner *scan = [NSScanner scannerWithString:txt];
    NSString *block;

    [scan scanUpToString:@"\n@@" intoString:&block];
    [res appendString:@"<table class='diff'><thead>"];
    [res appendString:[self parseDiffHeader:block]];
    [res appendString:@"</td></tr></thead><tbody>"];

    if ([block rangeOfString:@"Binary files"].location != NSNotFound) {
        [res appendString:[XTHTML parseBinaryDiff:block]];
    }

    while ([scan scanString:@"@@" intoString:NULL]) {
        [scan scanUpToString:@"\n@@" intoString:&block];
        [res appendString:[XTHTML parseDiffChunk:[NSString stringWithFormat:@"@@%@", block]]];
    }

    [res appendString:@"</tbody></table>"];

    return res;
}

+ (NSString *)getFileName:(NSString *)line {
    NSRange b = [line rangeOfString:@"b/"];

    if (b.length == 0)
        b = [line rangeOfString:@"--cc "];

    NSString *file = [line substringFromIndex:b.location + b.length];

    DLog(@"line=%@", line);
    DLog(@"file=%@", file);

    return file;
}


+ (NSString *)parseDiffHeader:(NSString *)txt {
    NSEnumerator *lines = [[txt componentsSeparatedByString:@"\n"] objectEnumerator];
    NSMutableString *res = [NSMutableString string];

    NSString *line = [lines nextObject];
    NSString *fileName = [XTHTML getFileName:line];

    [res appendString:[NSString stringWithFormat:@"<tr id='%@'><td colspan='33'><div style='float:left;'>", fileName]];
    do {
        [res appendString:[NSString stringWithFormat:@"<p>%@</p>", line]];
    } while ((line = [lines nextObject]));
    [res appendString:@"</div></td></tr>"];

    return res;
}

+ (NSString *)escapeHTML:(NSString *)txt {
    if (txt == nil)
        return txt;
    NSMutableString *newTxt = [NSMutableString stringWithString:txt];
    [newTxt replaceOccurrencesOfString:@"&" withString:@"&amp;" options:NSLiteralSearch range:NSMakeRange(0, [newTxt length])];
    [newTxt replaceOccurrencesOfString:@"<" withString:@"&lt;" options:NSLiteralSearch range:NSMakeRange(0, [newTxt length])];
    [newTxt replaceOccurrencesOfString:@">" withString:@"&gt;" options:NSLiteralSearch range:NSMakeRange(0, [newTxt length])];
    [newTxt replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange(0, [newTxt length])];
    [newTxt replaceOccurrencesOfString:@"'" withString:@"&apos;" options:NSLiteralSearch range:NSMakeRange(0, [newTxt length])];

    return newTxt;
}


+ (NSString *)parseBinaryDiff:(NSString *)txt {
    NSMutableString *res = [NSMutableString string];
    NSScanner *scan = [NSScanner scannerWithString:txt];
    NSString *block;

    [scan scanUpToString:@"Binary files" intoString:NULL];
    [scan scanUpToString:@"" intoString:&block];

    NSArray *files = [XTHTML getFilesNames:block];

    if ([files count] != 2)
        return txt;
    [res appendString:@"<tr class='images'><td>"];
    [res appendString:[NSString stringWithFormat:@"%@<br/>", files[0]]];
    if (![files[0] isAbsolutePath]) {
        if ([XTHTML isImage:files[0]]) {
            [res appendString:[NSString stringWithFormat:@"<img src='GitX://{SHA}:/prev/%@'/>", files[0]]];
        }
    }
    [res appendString:@"</td><td>=&gt;</td><td>"];
    [res appendString:[NSString stringWithFormat:@"%@<br/>", files[1]]];
    if (![files[1] isAbsolutePath]) {
        if ([XTHTML isImage:files[1]]) {
            [res appendString:[NSString stringWithFormat:@"<img src='GitX://{SHA}:/%@'/>", files[1]]];
        }
    }
    [res appendString:@"</td></tr>"];

    return res;
}

+ (NSString *)parseDiffChunk:(NSString *)txt {
    NSEnumerator *lines = [[txt componentsSeparatedByString:@"\n"] objectEnumerator];
    NSMutableString *res = [NSMutableString string];

    NSString *line;
    int r_line;

    line = [lines nextObject];
    DLog(@"-=%@=-", line);

    int arity = 0;     // How many files are merged here? Count the '@'!
    while ([line characterAtIndex:arity] == '@')
        arity++;

    int *l_line = (int *) malloc(arity * sizeof(int));
    NSRange hr = NSMakeRange(arity + 1, [line rangeOfString:@" @@"].location - arity - 1);
    NSString *header = [line substringWithRange:hr];

    NSArray *pos = [header componentsSeparatedByString:@" "];
    NSArray *pos_r = [pos[arity - 1] componentsSeparatedByString:@","];

    for (int i = 0; i < arity - 1; i++) {
        NSArray *pos_l = [pos[i] componentsSeparatedByString:@","];
        l_line[i] = abs([pos_l[0] intValue]);
    }
    r_line = [pos_r[0] intValue];

    [res appendString:[NSString stringWithFormat:@"<tr class='header'><td colspan='%d'>%@</td></tr>", arity + 1, line]];
    while ((line = [lines nextObject])) {
        if ([line length] > 0) {
            NSString *prefix = [line substringToIndex:arity - 1];
            if ([prefix rangeOfString:@"-"].location != NSNotFound) {
                [res appendString:@"<tr class='l'>"];
                for (int i = 0; i < arity - 1; i++) {
                    if ([prefix characterAtIndex:i] == '-') {
                        [res appendString:[NSString stringWithFormat:@"<td class='l'>%d</td>", l_line[i]++]];
                    } else {
                        [res appendString:@"<td class='l'></td>"];
                    }
                }
                [res appendString:@"<td class='r'></td>"];
            } else if ([prefix rangeOfString:@"+"].location != NSNotFound) {
                [res appendString:@"<tr class='r'>"];
                for (int i = 0; i < arity - 1; i++) {
                    if ([prefix characterAtIndex:i] == ' ') {
                        [res appendString:[NSString stringWithFormat:@"<td class='l'>%d</td>", l_line[i]++]];
                    } else {
                        [res appendString:@"<td class='l'></td>"];
                    }
                }
                [res appendString:[NSString stringWithFormat:@"<td class='r'>%d</td>", r_line++]];
            } else {
                [res appendString:@"<tr>"];
                for (int i = 0; i < arity - 1; i++) {
                    [res appendString:[NSString stringWithFormat:@"<td class='l'>%d</td>", l_line[i]++]];
                }
                [res appendString:[NSString stringWithFormat:@"<td class='r'>%d</td>", r_line++]];
            }
            if (![prefix hasPrefix:@"\\"]) {
                [res appendString:[NSString stringWithFormat:@"<td class='code'>%@</td></tr>", [line substringFromIndex:arity - 1]]];
            }
        }
    }
    free(l_line);
    return res;
}

+ (BOOL)isImage:(NSString *)file {
    NSString *mimeType = [self mimeTypeForFileName:file];

    return (mimeType != nil) && ([mimeType rangeOfString:@"image/" options:NSCaseInsensitiveSearch].location != NSNotFound);
}

+ (NSArray *)getFilesNames:(NSString *)line {
    NSString *a = nil;
    NSString *b = nil;
    NSScanner *scanner = [NSScanner scannerWithString:line];

    if ([scanner scanString:@"Binary files " intoString:NULL]) {
        [scanner scanUpToString:@" and" intoString:&a];
        [scanner scanString:@"and" intoString:NULL];
        [scanner scanUpToString:@" differ" intoString:&b];
    }
    if (![a isAbsolutePath]) {
        a = [a substringFromIndex:2];
    }
    if (![b isAbsolutePath]) {
        b = [b substringFromIndex:2];
    }

    return @[a, b];
}



+ (NSString *)mimeTypeForFileName:(NSString *)name {
    NSString *mimeType = nil;
    NSInteger i = [name rangeOfString:@"." options:NSBackwardsSearch].location;

    if (i != NSNotFound) {
        NSString *ext = [name substringFromIndex:i + 1];
        CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL);
        if (UTI) {
            CFStringRef registeredType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
            if (registeredType) {
                mimeType = CFBridgingRelease(registeredType);
            }
            CFRelease(UTI);
        }
    }
    return mimeType;
}



@end
