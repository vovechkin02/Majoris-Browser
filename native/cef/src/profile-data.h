#pragma once
#include <glib.h>
int majoris_profile_acquire(const char *path,GError **error);
void majoris_profile_release(int descriptor);
