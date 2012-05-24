//
//  XTCommitViewController.m
//  Xit
//
//  Created by German Laullon on 03/08/11.
//

#import "XTCommitViewController.h"
#import "NSMutableDictionary+MultiObjectForKey.h"
#import "XTSideBarItem.h"
#import "XTHTML.h"

// -parseHeader: returns an array of dictionaries with these keys
const NSString *kHeaderKeyName = @"name";
const NSString *kHeaderKeyContent = @"content";

// Keys for the author/committer dictionary
const NSString *kAuthorKeyName = @"name";
const NSString *kAuthorKeyEmail = @"email";
const NSString *kAuthorKeyDate = @"date";

@interface XTCommitViewController (Private)

- (NSArray *)parseHeader:(NSString *)text;
- (NSString *)htmlForHeader:(NSArray *)header;
- (NSMutableDictionary *)parseStats:(NSString *)txt;
- (NSString *)parseDiffTree:(NSString *)txt withStats:(NSMutableDictionary *)stats;

@end

@implementation XTCommitViewController

- (void)setRepo:(XTRepository *)newRepo {
    repo = newRepo;
    [repo addObserver:self forKeyPath:@"selectedCommit" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"selectedCommit"]) {
        NSString *newSelectedCommit = [change objectForKey:NSKeyValueChangeNewKey];
        dispatch_async(repo.queue, ^{ [self loadCommit:newSelectedCommit]; });
    }
}

// defaults write com.yourcompany.programname WebKitDeveloperExtras -bool true
- (NSString *)loadCommit:(NSString *)sha {
    NSData *output = [repo executeGitWithArgs:[NSArray arrayWithObjects:@"show", @"-z", @"--numstat", @"--summary", @"--pretty=raw", sha, nil] error:nil];

    if (output == nil)
        return nil;

    NSString *html = nil;
    NSString *txt = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    NSCharacterSet *nulSet = [NSCharacterSet characterSetWithRange:NSMakeRange(0, 1)];
    NSArray *details = [txt componentsSeparatedByCharactersInSet:nulSet];

    for (NSString *detail in details) {
        if ([detail hasPrefix:@"tag"]) {
            // TODO: parse tag header
        } else if ([detail hasPrefix:@"commit"]) {
            NSArray *headerItems = [self parseHeader:detail];
            NSString *header = [self htmlForHeader:headerItems];

            // File Stats
            NSMutableDictionary *stats = [self parseStats:detail];

            // File list
            output = [repo executeGitWithArgs:[NSArray arrayWithObjects:@"diff-tree", @"--root", @"-r", @"-C90%", @"-M90%", sha, nil] error:nil];
            NSString *dt = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
            NSString *fileList = [self parseDiffTree:dt withStats:stats];

            // Diffs list
            output = [repo executeGitWithArgs:[NSArray arrayWithObjects:@"diff-tree", @"--root", @"--cc", @"-C90%", @"-M90%", sha, nil] error:nil];
            NSString *d = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
            NSString *diffs = [XTHTML parseDiff:d];

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

            dispatch_async(dispatch_get_main_queue(), ^{
                               [[web mainFrame] loadHTMLString:html baseURL:themeURL];
                           });
            break;
        }
    }
    return html;
}

- (NSArray *)parseHeader:(NSString *)text {
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

- (NSMutableDictionary *)parseStats:(NSString *)txt {
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

- (NSString *)htmlForHeader:(NSArray *)header {
    NSString *last_mail = @"";
    NSMutableString *auths = [NSMutableString string];
    NSMutableString *refs = [NSMutableString string];
    NSMutableString *subject = [NSMutableString string];

    for (NSDictionary *item in header) {
        if ([[item objectForKey:kHeaderKeyName] isEqualToString:@"subject"]) {
            [subject appendString:[NSString stringWithFormat:@"%@<br/>", [XTHTML escapeHTML:[item objectForKey:kHeaderKeyContent]]]];
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

- (NSString *)parseDiffTree:(NSString *)txt withStats:(NSMutableDictionary *)stats {
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

@end
