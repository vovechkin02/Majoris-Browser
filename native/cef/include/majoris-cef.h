#pragma once
#include <glib-object.h>
G_BEGIN_DECLS
#define MC_TYPE_VIEW (mc_view_get_type())
G_DECLARE_FINAL_TYPE(McView, mc_view, MC, VIEW, GObject)
gboolean mc_runtime_initialize(const char *root, const char *helper, const char *resources, GError **error);
void mc_runtime_shutdown(void);
const char *mc_runtime_version(void);
McView *mc_view_new(const char *profile, gboolean ephemeral, const char *url, const char *scope);
void mc_view_close(McView *self);
void mc_view_load(McView *self, const char *url);
void mc_view_command(McView *self, const char *command);
void mc_view_resize(McView *self, int width, int height, double scale);
void mc_view_pointer(McView *self, int kind, int x, int y, int button, int modifiers, int dx, int dy);
void mc_view_key(McView *self, int kind, int key, int hardware, int modifiers);
void mc_view_text(McView *self, const char *text);
void mc_view_focus(McView *self, gboolean focused);
void mc_view_reply(McView *self, int token, gboolean accepted, const char *text);
void mc_view_clear_cookies(McView *self);
void mc_view_set_cookie(McView *self, const char *url, const char *name, const char *value);
void mc_view_get_cookies(McView *self, const char *url);
void mc_view_allow_auth(McView *self, const char *url);
gboolean mc_profile_clear(const char *path, GError **error);
void mc_view_autofill(McView *self, const char *origin, const char *username, const char *password);
void mc_view_fetch_manifest(McView *self, const char *url);
G_END_DECLS
