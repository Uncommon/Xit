#import "XTFileListDataSourceBase.h"
#import "XTRepository.h"

@implementation XTFileListDataSourceBase

- (void)dealloc
{
  [self.repository removeObserver:self forKeyPath:@"selectedCommit"];
}

- (void)reload
{
}

- (void)setRepository:(XTRepository*)repository
{
  _repository = repository;
  [_repository addObserver:self
               forKeyPath:@"selectedCommit"
                  options:NSKeyValueObservingOptionNew
                  context:nil];
  [self reload];
}

- (XTFileChange*)fileChangeAtRow:(NSInteger)row
{
  return nil;
}

@end
