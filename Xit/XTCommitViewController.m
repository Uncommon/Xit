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
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"

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

- (void)dealloc {
    [repo removeObserver:self forKeyPath:@"selectedCommit"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"selectedCommit"]) {
        NSString *newSelectedCommit = [change objectForKey:NSKeyValueChangeNewKey];
        dispatch_async(repo.queue, ^{ [self loadCommit:newSelectedCommit]; });
    }
}

- (NSString *)htmlForHeader:(NSDictionary *)header message:(NSString *)message {
    NSMutableString *table = [NSMutableString stringWithString:@"<td><table class='headercol'>"];
    NSString *firstLine = message;
    const NSRange lineEndRange = [message rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]];

    if (lineEndRange.location != NSNotFound)
        firstLine = [message substringToIndex:lineEndRange.location];

    void (^addRow)(NSString *, NSString *) = ^(NSString *label, NSString *content) {
        [table appendFormat:@"<tr><td>%@:</td><td>%@</td></tr>", label, content];
    };
    void (^addPerson)(NSString *,NSString *, NSString *, NSDate *) = ^(NSString *type, NSString *name, NSString *email, NSDate *date) {
        addRow(type, [NSString stringWithFormat:@"%@ &lt;%@&gt;", name, email]);
        addRow(@"Date", [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle]);
    };

    addRow(@"Subject", firstLine);

    NSString *authorName = [header objectForKey:XTAuthorNameKey];
    NSString *authorEmail = [header objectForKey:XTAuthorEmailKey];
    NSDate *authorDate = [header objectForKey:XTAuthorDateKey];

    addPerson(@"Author", authorName, authorEmail, authorDate);

    NSString *committerName = [header objectForKey:XTCommitterNameKey];
    NSString *committerEmail = [header objectForKey:XTCommitterEmailKey];
    NSDate *committerDate = [header objectForKey:XTCommitterDateKey];

    if ((committerName != nil) && (committerEmail != nil) && (committerDate != nil)) {
        if (![authorName isEqualToString:committerName] ||
            ![authorEmail isEqualToString:committerEmail] ||
            ![authorDate isEqual:committerDate])
            addPerson(@"Committer", committerName, committerEmail, committerDate);
    }

    [table appendString:@"</table></td>"];

    // Second colum: refs and SHAs
    [table appendString:@"<td><table class='headercol'>"];

    NSSet *refsSet = [header objectForKey:XTRefsKey];

    if ([refsSet count] > 0)
        // TODO: refs styled as tokens
        addRow(@"Refs", [[refsSet allObjects] componentsJoinedByString:@" "]);
    addRow(@"SHA", [header objectForKey:XTCommitSHAKey]);

    NSArray *parents = [header objectForKey:XTParentSHAsKey];

    for (NSString *parent in parents)
        // TODO: clickable SHA
        // TODO: parent subject and short SHA
        addRow(@"Parent", parent);

    [table appendString:@"</table></td>"];

    return [NSString stringWithFormat:@"<table class='header'><tr>%@</tr></table><p class='subject'>%@</p>", table, message];
}

- (NSString *)htmlForFiles:(NSArray *)files {
    NSMutableString *html = [NSMutableString string];

    for (NSString *file in files) {
        [html appendFormat:@"<p><a class='%@' href='#%@' representedfile='%@'>%@</a></p>",
                @"M", file, file, file];
    }

    return html;
}

// defaults write com.yourcompany.programname WebKitDeveloperExtras -bool true
- (NSString *)loadCommit:(NSString *)sha {
    NSDictionary *header = nil;
    NSString *message = nil;
    NSArray *files = nil;

    if (![repo parseCommit:sha intoHeader:&header message:&message files:&files])
        return nil;

    NSString *headerHTML = [self htmlForHeader:header message:message];
    NSString *filesHTML = [self htmlForFiles:files];

    NSString *diffString = [repo diffForCommit:sha];
    NSString *diffHTML = [XTHTML parseDiff:diffString];

    NSString *html = [NSString stringWithFormat:@"<html><head><link rel='stylesheet' type='text/css' href='diff.css'/></head><body>%@%@<div id='diffs'>%@</div></body></html>", headerHTML, filesHTML, diffHTML];

    NSBundle *bundle = [NSBundle mainBundle];
    NSBundle *theme = [NSBundle bundleWithURL:[bundle URLForResource:@"html.theme.default" withExtension:@"bundle"]];
    NSURL *themeURL = [theme resourceURL];

    dispatch_async(dispatch_get_main_queue(), ^{
                       [[web mainFrame] loadHTMLString:html baseURL:themeURL];
                   });
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
    for (__strong NSString *line in lines) {
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
        [res appendString:[NSString stringWithFormat:@"<span class='add' style='width:%d%%'></span>", (int)((add * 100) / granTotal)]];
        [res appendString:[NSString stringWithFormat:@"<span class='rem' style='width:%d%%'></span>", (int)((rem * 100) / granTotal)]];
        [res appendString:@"</div>"];
        [res appendString:[NSString stringWithFormat:@"</td><td class='add'>+ %d</td><td class='rem'>- %d</td></tr>", (int)add, (int)rem]];
    }
    [res appendString:@"</table>"];
    return res;
}

@end
