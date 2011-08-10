//
//  XTCommitViewController.m
//  Xit
//
//  Created by German Laullon on 03/08/11.
//

#import "XTCommitViewController.h"
#import "NSMutableDictionary+MultiObjectForKey.h"
#import "XTSideBarItem.h"

@interface XTCommitViewController (Private)

- (NSArray *) parseHeader:(NSString *)text;
- (NSString *) htmlForHeader:(NSArray *)header;
- (NSMutableDictionary *) parseStats:(NSString *)txt;
- (NSString *) parseDiff:(NSString *)txt;
- (BOOL) isImage:(NSString *)file;
- (NSString *) parseDiffBlock:(NSString *)txt;
- (NSString *) parseDiffHeader:(NSString *)txt;
- (NSString *) parseDiffChunk:(NSString *)txt;
- (NSString *) parseBinaryDiff:(NSString *)txt;
- (NSArray *) getFilesNames:(NSString *)line;
- (NSString *) parseDiffTree:(NSString *)txt withStats:(NSMutableDictionary *)stats;
- (NSString *) escapeHTML:(NSString *)txt;
- (NSString *) getFileName:(NSString *)line;

- (NSString *) mimeTypeForFileName:(NSString *)name;

@end

// -parseHeader: returns an array of dictionaries with these keys
const NSString * kHeaderKeyName = @"name";
const NSString *kHeaderKeyContent = @"content";

// Keys for the author/committer dictionary
const NSString *kAuthorKeyName = @"name";
const NSString *kAuthorKeyEmail = @"email";
const NSString *kAuthorKeyDate = @"date";

@implementation XTCommitViewController

- (void) setRepo:(Xit *)newRepo {
    repo = newRepo;
    [repo addObserver:self forKeyPath:@"selectedCommit" options:NSKeyValueObservingOptionNew context:nil];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"selectedCommit"]) {
        NSString *newSelectedCommit = [change objectForKey:NSKeyValueChangeNewKey];
        [self loadCommit:newSelectedCommit];
    }
}

// defaults write com.yourcompany.programname WebKitDeveloperExtras -bool true
- (NSString *) loadCommit:(NSString *)sha {
    NSString *html;
    NSData *output = [repo exectuteGitWithArgs:[NSArray arrayWithObjects:@"show", @"-z", @"--numstat", @"--summary", @"--pretty=raw", sha, nil] error:nil];

    if (output != nil) {
        NSString *txt = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        NSArray *details = [txt componentsSeparatedByString:@"\0"];
        for (NSString *detail in details) {
            if ([detail hasPrefix:@"tag"]) {
                // TODO: parse tag header
            } else if ([detail hasPrefix:@"commit"]) {
                NSArray *headerItems = [self parseHeader:detail];
                NSString *header = [self htmlForHeader:headerItems];

                // File Stats
                NSMutableDictionary *stats = [self parseStats:detail];

                // File list
                output = [repo exectuteGitWithArgs:[NSArray arrayWithObjects:@"diff-tree", @"--root", @"-r", @"-C90%", @"-M90%", sha, nil] error:nil];
                NSString *dt = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
                NSString *fileList = [self parseDiffTree:dt withStats:stats];

                // Diffs list
                output = [repo exectuteGitWithArgs:[NSArray arrayWithObjects:@"diff-tree", @"--root", @"--cc", @"-C90%", @"-M90%", sha, nil] error:nil];
                NSString *d = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
                NSString *diffs = [self parseDiff:d];

                // Badges
                NSArray *refs = [repo.refsIndex objectsForKey:sha];
                NSMutableString *badges = [NSMutableString string];
                if (refs.count > 0) {
                    [badges appendString:@"<div><ul>"];
                    for (XTSideBarItem *ref in refs) {
                        [badges appendFormat:@"<ul>%@</ul>", [ref badge]];
                    }
                    [badges appendString:@"</ul></div>"];
                }

                html = [NSString stringWithFormat:@"<html><head><link rel='stylesheet' type='text/css' href='diff.css'/></head><body>%@%@%@<div id='diffs'>%@</div></body></html>", header, badges, fileList, diffs];

                NSBundle *bundle = [NSBundle mainBundle];
                NSBundle *theme = [NSBundle bundleWithURL:[bundle URLForResource:@"html.theme.default" withExtension:@"bundle"]];
                NSURL *themeURL = [[theme bundleURL] URLByAppendingPathComponent:@"Contents/Resources"];

                [[web mainFrame] loadHTMLString:html baseURL:themeURL];
            }
        }
    }
    return html;
}

- (NSString *) htmlForHeader:(NSArray *)header {
    NSString *last_mail = @"";
    NSMutableString *auths = [NSMutableString string];
    NSMutableString *refs = [NSMutableString string];
    NSMutableString *subject = [NSMutableString string];

    for (NSDictionary *item in header) {
        if ([[item objectForKey:kHeaderKeyName] isEqualToString:@"subject"]) {
            [subject appendString:[NSString stringWithFormat:@"%@<br/>", [self escapeHTML:[item objectForKey:kHeaderKeyContent]]]];
        } else {
            if ([[item objectForKey:kHeaderKeyContent] isKindOfClass:[NSString class]]) {
                [refs appendString:[NSString stringWithFormat:@"<tr><td>%@</td><td><a href='' onclick='selectCommit(this.innerHTML); return false;'>%@</a></td></tr>", [item objectForKey:kHeaderKeyName], [item objectForKey:kHeaderKeyContent]]];
            } else {            // NSDictionary: author or committer
                NSDictionary *content = [item objectForKey:kHeaderKeyContent];
                NSString *email = [content objectForKey:kAuthorKeyEmail];

                if (![email isEqualToString:last_mail]) {
                    NSString *name = [content objectForKey:kAuthorKeyName];
                    NSDate *date = [content objectForKey:kAuthorKeyDate];
                    NSDateFormatter *theDateFormatter = [[NSDateFormatter alloc] init];
                    [theDateFormatter setDateStyle:NSDateFormatterMediumStyle];
                    [theDateFormatter setTimeStyle:NSDateFormatterMediumStyle];
                    NSString *dateString = [theDateFormatter stringForObjectValue:date];

                    [auths appendString:[NSString stringWithFormat:@"<div class='user %@ clearfix'>", [item objectForKey:kHeaderKeyName]]];
                    [auths appendString:[NSString stringWithFormat:@"<p class='name'>%@ <span class='rol'>(%@)</span></p>", name, [item objectForKey:kHeaderKeyName]]];
                    [auths appendString:[NSString stringWithFormat:@"<p class='time'>%@</p></div>", dateString]];
                }
                last_mail = email;
            }
        }
    }

    return [NSString stringWithFormat:@"<div id='header' class='clearfix'><table class='references'>%@</table><p class='subject'>%@</p>%@</div>", refs, subject, auths];
}

- (NSArray *) parseHeader:(NSString *)text {
    NSMutableArray *result = [NSMutableArray array];
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    BOOL parsingSubject = NO;

    for (NSString *line in lines) {
        if ([line length] == 0) {
            if (!parsingSubject)
                parsingSubject = TRUE;
            else
                break;
        } else {
            if (parsingSubject) {
                NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                [result addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                   @"subject", kHeaderKeyName, trimmedLine, kHeaderKeyContent, nil]];
            } else {
                NSArray *comps = [line componentsSeparatedByString:@" "];
                if ([comps count] == 2) {
                    [result addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [comps objectAtIndex:0], kHeaderKeyName,
                                       [comps objectAtIndex:1], kHeaderKeyContent, nil]];
                } else if ([comps count] > 2) {
                    NSRange r_email_i = [line rangeOfString:@"<"];
                    NSRange r_email_e = [line rangeOfString:@">"];
                    NSRange r_name_i = [line rangeOfString:@" "];

                    NSString *name = [line substringWithRange:NSMakeRange(r_name_i.location, (r_email_i.location - r_name_i.location))];
                    NSString *email = [line substringWithRange:NSMakeRange(r_email_i.location + 1, ((r_email_e.location - 1) - r_email_i.location))];

                    NSDate *date = nil;

                    if ([line length] > r_email_e.location + 2) {
                        NSArray *t = [[line substringFromIndex:r_email_e.location + 2] componentsSeparatedByString:@" "];
                        if ([t count] > 0)
                            date = [NSDate dateWithTimeIntervalSince1970:[[t objectAtIndex:0] doubleValue]];
                    }

                    NSDictionary *content = [NSDictionary dictionaryWithObjectsAndKeys:
                                             name, kAuthorKeyName,
                                             email, kAuthorKeyEmail,
                                             date, kAuthorKeyDate,
                                             nil];
                    [result addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [comps objectAtIndex:0], kHeaderKeyName,
                                       content, kHeaderKeyContent,
                                       nil]];
                }
            }
        }
    }

    return result;
}

- (NSMutableDictionary *) parseStats:(NSString *)txt {
    NSArray *lines = [txt componentsSeparatedByString:@"\n"];
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    int black = 0;

    for (NSString *line in lines) {
        if ([line length] == 0) {
            black++;
        } else if (black == 2) {
            NSArray *file = [line componentsSeparatedByString:@"\t"];
            if ([file count] == 3) {
                [stats setObject:file forKey:[file objectAtIndex:2]];
            }
        }
    }
    return stats;
}

- (NSString *) escapeHTML:(NSString *)txt {
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

- (NSString *) parseDiff:(NSString *)txt {
    txt = [self escapeHTML:txt];

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

- (NSString *) parseDiffBlock:(NSString *)txt {
    NSMutableString *res = [NSMutableString string];
    NSScanner *scan = [NSScanner scannerWithString:txt];
    NSString *block;

    [scan scanUpToString:@"\n@@" intoString:&block];
    [res appendString:@"<table class='diff'><thead>"];
    [res appendString:[self parseDiffHeader:block]];
    [res appendString:@"</td></tr></thead><tbody>"];

    if ([block rangeOfString:@"Binary files"].location != NSNotFound) {
        [res appendString:[self parseBinaryDiff:block]];
    }

    while ([scan scanString:@"@@" intoString:NULL]) {
        [scan scanUpToString:@"\n@@" intoString:&block];
        [res appendString:[self parseDiffChunk:[NSString stringWithFormat:@"@@%@", block]]];
    }

    [res appendString:@"</tbody></table>"];

    return res;
}

- (NSString *) parseBinaryDiff:(NSString *)txt {
    NSMutableString *res = [NSMutableString string];
    NSScanner *scan = [NSScanner scannerWithString:txt];
    NSString *block;

    [scan scanUpToString:@"Binary files" intoString:NULL];
    [scan scanUpToString:@"" intoString:&block];

    NSArray *files = [self getFilesNames:block];
    [res appendString:@"<tr class='images'><td>"];
    [res appendString:[NSString stringWithFormat:@"%@<br/>", [files objectAtIndex:0]]];
    if (![[files objectAtIndex:0] isAbsolutePath]) {
        if ([self isImage:[files objectAtIndex:0]]) {
            [res appendString:[NSString stringWithFormat:@"<img src='GitX://{SHA}:/prev/%@'/>", [files objectAtIndex:0]]];
        }
    }
    [res appendString:@"</td><td>=&gt;</td><td>"];
    [res appendString:[NSString stringWithFormat:@"%@<br/>", [files objectAtIndex:1]]];
    if (![[files objectAtIndex:1] isAbsolutePath]) {
        if ([self isImage:[files objectAtIndex:1]]) {
            [res appendString:[NSString stringWithFormat:@"<img src='GitX://{SHA}:/%@'/>", [files objectAtIndex:1]]];
        }
    }
    [res appendString:@"</td></tr>"];

    return res;
}

- (NSString *) parseDiffChunk:(NSString *)txt {
    NSEnumerator *lines = [[txt componentsSeparatedByString:@"\n"] objectEnumerator];
    NSMutableString *res = [NSMutableString string];

    NSString *line;
    int l_line[32]; // FIXME: make dynamic
    int r_line;

    line = [lines nextObject];
    DLog(@"-=%@=-", line);

    int arity = 0;     /* How many files are merged here? Count the '@'! */
    while ([line characterAtIndex:arity] == '@')
        arity++;

    NSRange hr = NSMakeRange(arity + 1, [line rangeOfString:@" @@"].location - arity - 1);
    NSString *header = [line substringWithRange:hr];

    NSArray *pos = [header componentsSeparatedByString:@" "];
    NSArray *pos_r = [[pos objectAtIndex:arity - 1] componentsSeparatedByString:@","];

    for (int i = 0; i < arity - 1; i++) {
        NSArray *pos_l = [[pos objectAtIndex:i] componentsSeparatedByString:@","];
        l_line[i] = abs([[pos_l objectAtIndex:0] intValue]);
    }
    r_line = [[pos_r objectAtIndex:0] intValue];

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
    return res;
}

- (NSArray *) getFilesNames:(NSString *)line {
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

    return [NSArray arrayWithObjects:a, b, nil];
}

- (NSString *) parseDiffTree:(NSString *)txt withStats:(NSMutableDictionary *)stats {
    NSInteger granTotal = 1;

    for (NSArray *stat in [stats allValues]) {
        NSInteger add = [[stat objectAtIndex:0] integerValue];
        NSInteger rem = [[stat objectAtIndex:1] integerValue];
        NSInteger tot = add + rem;
        if (tot > granTotal)
            granTotal = tot;
        [stats setObject:[NSArray arrayWithObjects:[NSNumber numberWithInteger:add], [NSNumber numberWithInteger:rem], [NSNumber numberWithInteger:tot], nil] forKey:[stat objectAtIndex:2]];
    }

    NSArray *lines = [txt componentsSeparatedByString:@"\n"];
    NSMutableString *res = [NSMutableString string];
    [res appendString:@"<table id='filelist'>"];
    for (NSString *line in lines) {
        if ([line length] < 98) continue;
        line = [line substringFromIndex:97];
        NSArray *fileStatus = [line componentsSeparatedByString:@"\t"];
        NSString *status = [[fileStatus objectAtIndex:0] substringToIndex:1];       // ignore the score
        NSString *file = [fileStatus objectAtIndex:1];
        NSString *txt = file;
        NSString *fileName = file;
        if ([status isEqualToString:@"C"] || [status isEqualToString:@"R"]) {
            txt = [NSString stringWithFormat:@"%@ -&gt; %@", file, [fileStatus objectAtIndex:2]];
            fileName = [fileStatus objectAtIndex:2];
        }

        NSArray *stat = [stats objectForKey:fileName];
        NSInteger add = [[stat objectAtIndex:0] integerValue];
        NSInteger rem = [[stat objectAtIndex:1] integerValue];

        [res appendString:@"<tr><td class='name'>"];
        [res appendString:[NSString stringWithFormat:@"<a class='%@' href='#%@' representedFile='%@'>%@</a>", status, file, fileName, txt]];
        [res appendString:@"</td><td class='bar'>"];
        [res appendString:@"<div>"];
        [res appendString:[NSString stringWithFormat:@"<span class='add' style='width:%d%%'></span>", ((add * 100) / granTotal)]];
        [res appendString:[NSString stringWithFormat:@"<span class='rem' style='width:%d%%'></span>", ((rem * 100) / granTotal)]];
        [res appendString:@"</div>"];
        [res appendString:[NSString stringWithFormat:@"</td><td class='add'>+ %d</td><td class='rem'>- %d</td></tr>", add, rem]];
    }
    [res appendString:@"</table>"];
    return res;
}

- (NSString *) parseDiffHeader:(NSString *)txt {
    NSEnumerator *lines = [[txt componentsSeparatedByString:@"\n"] objectEnumerator];
    NSMutableString *res = [NSMutableString string];

    NSString *line = [lines nextObject];
    NSString *fileName = [self getFileName:line];

    [res appendString:[NSString stringWithFormat:@"<tr id='%@'><td colspan='33'><div style='float:left;'>", fileName]];
    do {
        [res appendString:[NSString stringWithFormat:@"<p>%@</p>", line]];
    } while ((line = [lines nextObject]));
    [res appendString:@"</div></td></tr>"];

    return res;
}

- (NSString *) getFileName:(NSString *)line {
    NSRange b = [line rangeOfString:@"b/"];

    if (b.length == 0)
        b = [line rangeOfString:@"--cc "];

    NSString *file = [line substringFromIndex:b.location + b.length];

    DLog(@"line=%@", line);
    DLog(@"file=%@", file);

    return file;
}

- (NSString *) mimeTypeForFileName:(NSString *)name {
    NSString *mimeType = nil;
    NSInteger i = [name rangeOfString:@"." options:NSBackwardsSearch].location;

    if (i != NSNotFound) {
        NSString *ext = [name substringFromIndex:i + 1];
        CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)ext, NULL);
        if (UTI) {
            CFStringRef registeredType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
            if (registeredType) {
                mimeType = NSMakeCollectable(registeredType);
            }
            CFRelease(UTI);
        }
    }
    return mimeType;
}

- (BOOL) isImage:(NSString *)file {
    NSString *mimeType = [self mimeTypeForFileName:file];

    return (mimeType != nil) && ([mimeType rangeOfString:@"image/" options:NSCaseInsensitiveSearch].location != NSNotFound);
}

@end
