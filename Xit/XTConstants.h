//
//  XTConstants.h
//  Xit
//
//  Created by David Catmull on 1/24/13.
//
//

typedef enum {
    XTRefTypeBranch,
    XTRefTypeActiveBranch,
    XTRefTypeRemoteBranch,
    XTRefTypeTag,
    XTRefTypeRemote,
    XTRefTypeUnknown
} XTRefType;

typedef enum {
    XTBranchesGroupIndex,
    XTRemotesGroupIndex,
    XTTagsGroupIndex,
    XTStashesGroupIndex
} XTSideBarRootItems;
