#import <Cocoa/Cocoa.h>

extern NSString *XTErrorDomainXit, *XTErrorDomainGit;

/// Fake value for seleting staging view.
extern NSString * const XTStagingSHA;

/// There is a new selection to be displayed.
extern NSString * const XTSelectedModelChangedNotification;

/// The selection has been clicked again. Make sure it is visible.
extern NSString * const XTReselectModelNotification;

/// TeamCity build status has been downloaded/refreshed.
extern NSString * const XTTeamCityStatusChangedNotification;
