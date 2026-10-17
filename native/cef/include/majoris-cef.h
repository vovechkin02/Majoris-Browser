#pragma once
#include <glib-object.h>
G_BEGIN_DECLS
#define MC_TYPE_VIEW (mc_view_get_type())
G_DECLARE_FINAL_TYPE(McView, mc_view, MC, VIEW, GObject)
gboolean mc_runtime_initialize(const char *root, const char *helper, const char *resources, GError **error);
void mc_runtime_shutdown(void);
const char *mc_runtime_version(void);
McView *mc_view_new(const char *profile, gboolean ephemeral, const char *url, const char *scope);
McView *mc_view_new_with_permissions(const char *profile, gboolean ephemeral, const char *url, const char *scope, const char *permissions);
void mc_view_set_permissions(McView *self, const char *permissions);
void mc_view_close(McView *self);
void mc_view_request_close(McView *self);
void mc_view_load(McView *self, const char *url);
void mc_view_command(McView *self, const char *command);
void mc_view_resize(McView *self, int width, int height, double scale);
void mc_view_pointer(McView *self, int kind, int x, int y, int button, int modifiers, int dx, int dy);
void mc_view_key(McView *self, int kind, int key, int hardware, int modifiers);
void mc_view_text(McView *self, const char *text);
void mc_view_focus(McView *self, gboolean focused);
void mc_view_reply(McView *self, int token, gboolean accepted, const char *text);
void mc_view_clear_cookies(McView *self);
void mc_view_clear_site_cookies(McView *self, const char *url);
void mc_view_clear_site_data(McView *self, const char *url);
void mc_view_ime(McView *self, const char *text, int selection, gboolean commit);
void mc_view_fetch_image(McView *self, const char *url, const char *tag);
void mc_view_evaluate(McView *self, const char *expression);
void mc_view_drop(McView *self, const char *text, const char *files, int x, int y);
void mc_view_set_cookie(McView *self, const char *url, const char *name, const char *value);
void mc_view_set_cookie_details(McView *self, const char *url, const char *name, const char *value, const char *domain, const char *path, gboolean secure, gboolean http_only);
void mc_view_get_cookies(McView *self, const char *url);
void mc_view_allow_auth(McView *self, const char *url);
gboolean mc_profile_clear(const char *path, GError **error);
int mc_profile_acquire(const char *path, GError **error);
void mc_profile_release(int descriptor);
gboolean mc_profile_clear_locked(const char *path, GError **error);
void mc_view_autofill(McView *self, const char *origin, const char *username, const char *password);
void mc_view_fill_address(McView *self, const char *origin, const char *fields);
void mc_view_fetch_manifest(McView *self, const char *url);
G_END_DECLS
