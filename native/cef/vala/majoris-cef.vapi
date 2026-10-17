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
    [CCode (cname = "McView", cprefix = "mc_view_", lower_case_cprefix = "mc_view_", type_id = "mc_view_get_type ()")]
    public class View : GLib.Object {
        [CCode (cname = "mc_view_new")]
        public View (string profile, bool ephemeral, string url, string scope = "");
        public void close ();
        public void load (string url);
        public void command (string command);
        public void resize (int width, int height, double scale);
        public void pointer (int kind, int x, int y, int button, int modifiers, int dx, int dy);
        public void key (int kind, int key, int hardware, int modifiers);
        public void text (string text);
        public void focus (bool focused);
        public void reply (int token, bool accepted, string text);
        public void clear_cookies ();
        public void set_cookie (string url, string name, string value);
        public void get_cookies (string url);
        public void allow_auth (string url);
        public void autofill (string origin, string username, string password);
        public void fetch_manifest (string url);
        public signal void frame (GLib.Bytes pixels, int width, int height);
        public signal void event (string kind, string value);
        public signal void request (int token, string kind, string origin, string message);
    }
}
