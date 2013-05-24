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
        NSString *newSelectedCommit = change[NSKeyValueChangeNewKey];
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

    NSString *authorName = header[XTAuthorNameKey];
    NSString *authorEmail = header[XTAuthorEmailKey];
    NSDate *authorDate = header[XTAuthorDateKey];

    addPerson(@"Author", authorName, authorEmail, authorDate);

    NSString *committerName = header[XTCommitterNameKey];
    NSString *committerEmail = header[XTCommitterEmailKey];
    NSDate *committerDate = header[XTCommitterDateKey];

    if ((committerName != nil) && (committerEmail != nil) && (committerDate != nil)) {
        if (![authorName isEqualToString:committerName] ||
            ![authorEmail isEqualToString:committerEmail] ||
            ![authorDate isEqual:committerDate])
            addPerson(@"Committer", committerName, committerEmail, committerDate);
    }

    [table appendString:@"</table></td>"];

    // Second colum: refs and SHAs
    [table appendString:@"<td><table class='headercol'>"];

    NSSet *refsSet = header[XTRefsKey];

    if ([refsSet count] > 0)
        addRow(@"Refs", [[refsSet allObjects] componentsJoinedByString:@" "]);
    addRow(@"SHA", header[XTCommitSHAKey]);

    NSArray *parents = header[XTParentSHAsKey];

    for (NSString *parent in parents)
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
    NSURL *htmlURL = [bundle URLForResource:@"html" withExtension:nil];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[web mainFrame] loadHTMLString:html baseURL:htmlURL];
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
                [result addObject:@{kHeaderKeyName: @"subject", kHeaderKeyContent: trimmedLine}];
            } else {
                NSArray *comps = [line componentsSeparatedByString:@" "];
                if ([comps count] == 2) {
                    [result addObject:@{kHeaderKeyName: comps[0],
                                       kHeaderKeyContent: comps[1]}];
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
                            date = [NSDate dateWithTimeIntervalSince1970:[t[0] doubleValue]];
                    }

                    NSDictionary *content = @{kAuthorKeyName: name,
                                             kAuthorKeyEmail: email,
                                             kAuthorKeyDate: date};
                    [result addObject:@{kHeaderKeyName: comps[0],
                                       kHeaderKeyContent: content}];
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
                stats[file[2]] = file;
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
        if ([item[kHeaderKeyName] isEqualToString:@"subject"]) {
            [subject appendString:[NSString stringWithFormat:@"%@<br/>", [XTHTML escapeHTML:item[kHeaderKeyContent]]]];
        } else {
            if ([item[kHeaderKeyContent] isKindOfClass:[NSString class]]) {
                [refs appendString:[NSString stringWithFormat:@"<tr><td>%@</td><td><a href='' onclick='selectCommit(this.innerHTML); return false;'>%@</a></td></tr>", item[kHeaderKeyName], item[kHeaderKeyContent]]];
            } else {            // NSDictionary: author or committer
                NSDictionary *content = item[kHeaderKeyContent];
                NSString *email = content[kAuthorKeyEmail];

                if (![email isEqualToString:last_mail]) {
                    NSString *name = content[kAuthorKeyName];
                    NSDate *date = content[kAuthorKeyDate];
                    NSDateFormatter *theDateFormatter = [[NSDateFormatter alloc] init];
                    [theDateFormatter setDateStyle:NSDateFormatterMediumStyle];
                    [theDateFormatter setTimeStyle:NSDateFormatterMediumStyle];
                    NSString *dateString = [theDateFormatter stringForObjectValue:date];

                    [auths appendString:[NSString stringWithFormat:@"<div class='user %@ clearfix'>", item[kHeaderKeyName]]];
                    [auths appendString:[NSString stringWithFormat:@"<p class='name'>%@ <span class='rol'>(%@)</span></p>", name, item[kHeaderKeyName]]];
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
        NSInteger add = [stat[0] integerValue];
        NSInteger rem = [stat[1] integerValue];
        NSInteger tot = add + rem;
        if (tot > granTotal)
            granTotal = tot;
        stats[stat[2]] = @[@(add), @(rem), @(tot)];
    }

    NSArray *lines = [txt componentsSeparatedByString:@"\n"];
    NSMutableString *res = [NSMutableString string];
    [res appendString:@"<table id='filelist'>"];
    for (__strong NSString *line in lines) {
        if ([line length] < 98) continue;
        line = [line substringFromIndex:97];
        NSArray *fileStatus = [line componentsSeparatedByString:@"\t"];
        NSString *status = [fileStatus[0] substringToIndex:1];       // ignore the score
        NSString *file = fileStatus[1];
        NSString *txt = file;
        NSString *fileName = file;
        if ([status isEqualToString:@"C"] || [status isEqualToString:@"R"]) {
            txt = [NSString stringWithFormat:@"%@ -&gt; %@", file, fileStatus[2]];
            fileName = fileStatus[2];
        }

        NSArray *stat = stats[fileName];
        NSInteger add = [stat[0] integerValue];
        NSInteger rem = [stat[1] integerValue];

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

#pragma mark - WebUIDelegate

- (NSUInteger)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo {
    return WebDragDestinationActionNone;
}

@end
