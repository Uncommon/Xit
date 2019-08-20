#ifndef LibGitExtensions_h
#define LibGitExtensions_h

#import <git2/oid.h>

bool xit_oid_equal(const git_oid *a, const git_oid *b);

bool git_buffer_is_binary(const char *buf, size_t size);


#endif /* LibGitExtensions_h */
