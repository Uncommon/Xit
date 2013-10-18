//
//  PBGitGrapher.m
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//

#import "PBGitGrapher.h"
#import "PBGitLane.h"
#import "PBGitGraphLine.h"
#import <list>

using namespace std;

@implementation PBGitGrapher

#define MAX_LANES 100

- (id)init {
    self = [super init];
    if (self) {
        pl = new std::list<PBGitLane *>;
        PBGitLane::resetColors();
    }

    return self;
}

void add_line(struct PBGitGraphLine *lines, int *nLines, int upper, size_t from, size_t to, int index){
    // TODO: put in one thing
    struct PBGitGraphLine a = { upper, from, to, index };

    lines[(*nLines)++] = a;
}

- (void)decorateCommit:(XTHistoryItem *)commit {
    int i = 0;
    size_t newPos = -1;

    std::list<PBGitLane *> *currentLanes = new std::list<PBGitLane *>;
    std::list<PBGitLane *> *previousLanes = (std::list<PBGitLane *> *)pl;
    NSArray *parents = [commit parents];
    NSUInteger nParents = [parents count];

    NSUInteger maxLines = (previousLanes->size() + nParents + 2) * 2;
    struct PBGitGraphLine *lines = (struct PBGitGraphLine *)malloc(sizeof(struct PBGitGraphLine) * maxLines);
    int currentLine = 0;

    PBGitLane *currentLane = NULL;
    BOOL didFirst = NO;
    NSString *commit_oid = [commit sha];

    // First, iterate over earlier columns and pass through any that don't want this commit
    if (previous != nil) {
        // We can't count until numColumns here, as it's only used for the width of the cell.
        std::list<PBGitLane *>::iterator it = previousLanes->begin();
        for (; it != previousLanes->end(); ++it) {
            i++;
            // This is our commit! We should do a "merge": move the line from
            // our upperMapping to their lowerMapping
            if ((*it)->isCommit(commit_oid)) {
                if (!didFirst) {
                    didFirst = YES;
                    currentLanes->push_back(*it);
                    currentLane = currentLanes->back();
                    newPos = currentLanes->size();
                    add_line(lines, &currentLine, 1, i, newPos, (*it)->index());
                    if (nParents)
                        add_line(lines, &currentLine, 0, newPos, newPos, (*it)->index());
                } else {
                    add_line(lines, &currentLine, 1, i, newPos, (*it)->index());
                    delete *it;
                }
            } else {
                // We are not this commit.
                currentLanes->push_back(*it);
                add_line(lines, &currentLine, 1, i, currentLanes->size(), (*it)->index());
                add_line(lines, &currentLine, 0, currentLanes->size(), currentLanes->size(), (*it)->index());
            }
            // For existing columns, we always just continue straight down
            // ^^ I don't know what that means anymore :(

        }
    }
    // Add your own parents

    // If we already did the first parent, don't do so again
    if (!didFirst && currentLanes->size() < MAX_LANES && nParents) {
        XTHistoryItem *parent = parents[0];
        PBGitLane *newLane = new PBGitLane(parent.sha);
        currentLanes->push_back(newLane);
        newPos = currentLanes->size();
        add_line(lines, &currentLine, 0, newPos, newPos, newLane->index());
    }

    // Add all other parents

    // If we add at least one parent, we can go back a single column.
    // This boolean will tell us if that happened
    BOOL addedParent = NO;

    int parentIndex = 0;
    for (parentIndex = 1; parentIndex < nParents; ++parentIndex) {
        XTHistoryItem *parent = parents[parentIndex];
        NSString *parentSha = parent.sha;
        int i = 0;
        BOOL was_displayed = NO;
        std::list<PBGitLane *>::iterator it = currentLanes->begin();
        for (; it != currentLanes->end(); ++it) {
            i++;
            if ((*it)->isCommit(parentSha)) {
                add_line(lines, &currentLine, 0, i, newPos, (*it)->index());
                was_displayed = YES;
                break;
            }
        }
        if (was_displayed)
            continue;

        if (currentLanes->size() >= MAX_LANES)
            break;

        // Really add this parent
        addedParent = YES;
        PBGitLane *newLane = new PBGitLane(parentSha);
        currentLanes->push_back(newLane);
        add_line(lines, &currentLine, 0, currentLanes->size(), newPos, newLane->index());
    }

    if (commit.lineInfo) {
        previous = commit.lineInfo;
        previous.position = newPos;
        previous.lines = lines;
    } else
        previous = [[PBGraphCellInfo alloc] initWithPosition:newPos andLines:lines];

    if (currentLine > maxLines)
        /*DLog*/NSLog(@"Number of lines: %i vs allocated: %lu", currentLine, maxLines);

    previous.nLines = currentLine;

    // If a parent was added, we have room to not indent.
    if (addedParent)
        previous.numColumns = currentLanes->size() - 1;
    else
        previous.numColumns = currentLanes->size();

    // Update the current lane to point to the new parent
    if (currentLane && nParents > 0) {
        XTHistoryItem *parent = parents[0];
        currentLane->setSha(parent.sha);
    } else {
        currentLanes->remove(currentLane);
    }

    delete previousLanes;

    pl = currentLanes;
    commit.lineInfo = previous;
}

- (void)dealloc {
    std::list<PBGitLane *> *lanes = (std::list<PBGitLane *> *)pl;
    std::list<PBGitLane *>::iterator it = lanes->begin();
    for (; it != lanes->end(); ++it) {
        delete *it;
    }

    delete lanes;

}
@end
