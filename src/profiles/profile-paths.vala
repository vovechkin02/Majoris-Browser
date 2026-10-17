namespace MajorisBrowser {
    public class ProfilePaths : Object {
        public string root { get; private set; }
        public ProfilePaths (string? data_home = null) {
            root = Path.build_filename (data_home ?? Environment.get_user_data_dir (), "majoris-browser");
        }
        public string browser_store { owned get { return Path.build_filename (root, "browser", "browser.db"); } }
        public string cef_root { owned get { return Path.build_filename (root, "cef"); } }
        public string browser_context { owned get { return Path.build_filename (cef_root, "browser"); } }
        public string webapp_context (string id) throws Error {
            if (!valid_id (id)) throw new BrowserError.INVALID_APP ("Invalid application identifier");
            return Path.build_filename (cef_root, "webapps", id);
        }
        public static bool valid_id (string id) {
            if (!id.has_prefix ("a") || id.length != 33) return false;
            for (int i = 1; i < id.length; i++) if (!id[i].isxdigit () || id[i].isupper ()) return false;
            return true;
        }
        public void prepare () throws Error {
            foreach (string path in new string[] { Path.get_dirname (browser_store), cef_root, browser_context })
                if (DirUtils.create_with_parents (path, 0700) != 0) throw new FileError.FAILED ("Cannot create profile directory");
        }
    }
}
