#include "LibGitExtensions.h"

// git_oid_equal compares byte by byte, so this is a little faster.
bool xit_oid_equal(const git_oid *a, const git_oid *b)
{
  return memcmp(a->id, b->id, sizeof(a->id)) == 0;
}

bool git_buffer_is_binary(const char *buffer, size_t size)
{
  git_buf buf;
  
  buf.ptr = (char*)buffer;
  buf.size = size;
  buf.asize = size;
  return git_buf_is_binary(&buf) != 0;
}
