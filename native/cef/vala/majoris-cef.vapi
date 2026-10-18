[CCode (cheader_filename = "majoris-cef.h")]
namespace MajorisCef {
    [CCode (cname = "mc_runtime_initialize")]
    public bool initialize (string root, string helper, string resources) throws GLib.Error;
    [CCode (cname = "mc_runtime_shutdown")]
    public void shutdown ();
    [CCode (cname = "mc_runtime_version")]
    public unowned string version ();
    [CCode (cname = "mc_profile_clear")]
    public bool clear_profile (string path) throws GLib.Error;
    [CCode (cname = "mc_profile_acquire")]
    public int acquire_profile(string path) throws GLib.Error;
    [CCode (cname = "mc_profile_release")]
    public void release_profile(int descriptor);
    [CCode (cname = "mc_profile_clear_locked")]
    public bool clear_locked_profile(string path) throws GLib.Error;
    [CCode (cname = "McView", cprefix = "mc_view_", lower_case_cprefix = "mc_view_", type_id = "mc_view_get_type ()")]
    public class View : GLib.Object {
        [CCode (cname = "mc_view_new")]
        public View (string profile, bool ephemeral, string url, string scope = "");
        [CCode(cname="mc_view_new_with_permissions")]
        public View.with_permissions(string profile,bool ephemeral,string url,string scope,string permissions);
        public void set_permissions(string permissions);
        public void close ();
        public void request_close ();
        public void drag_end(int x,int y,int operation);
        public void drag_target(int phase,string text,string files,int x,int y);
        public void set_accessibility(bool enabled);
        public void load (string url);
        public void command (string command);
        public void resize (int width, int height, double scale);
        public void pointer (int kind, int x, int y, int button, int modifiers, int dx, int dy);
        public void key (int kind, int key, int hardware, int modifiers);
        public void text (string text);
        public void focus (bool focused);
        public void reply (int token, bool accepted, string text);
        public void clear_cookies ();
        public void clear_http_cache ();
        public void clear_site_cookies (string url);
        public void clear_site_data (string url);
        public void ime (string text, int selection, bool commit);
        public void fetch_image (string url, string tag);
        public void evaluate (string expression);
        public void drop (string text, string files, int x, int y);
        public void set_cookie (string url, string name, string value);
        public void set_cookie_details(string url,string name,string value,string domain,string path,bool secure,bool http_only);
        public void cookie_inventory();
        public void set_partitioned_cookie(string url,string name,string value,string top_level_site);
        public void get_cookies (string url);
        public void allow_auth_for(string url,int seconds);
        public void allow_auth (string url);
        public bool is_auth_popup();
        public void autofill (string origin, string username, string password);
        public void fill_address (string origin, string fields);
        public void fetch_manifest (string url);
        public signal void frame (GLib.Bytes pixels, int width, int height);
        public signal void event (string kind, string value);
        public signal void request (int token, string kind, string origin, string message);
        public signal void popup(View child,bool background,string url,bool new_window);
    }
}
