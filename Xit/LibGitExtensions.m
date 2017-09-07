#include "LibGitExtensions.h"

// git_oid_equal compares byte by byte, so this is a little faster.
bool xit_oid_equal(const git_oid *a, const git_oid *b)
{
  return memcmp(a->id, b->id, sizeof(a->id)) == 0;
}
