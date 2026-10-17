namespace MajorisBrowser {
    public errordomain BrowserError { INVALID_URL, STORAGE, INVALID_APP }

    public class UrlResolver : Object {
        public static string resolve (string input, string search = "https://duckduckgo.com/?q=%s") {
            var text = input.strip ();
            if (text == "") return "about:blank";
            if (text == "about:blank") return text;
            if (text.has_prefix ("http://") || text.has_prefix ("https://") || text.has_prefix ("file://"))
                return text;
            if (!text.contains (" ") && !text.contains ("://") &&
                (text.contains (".") || text.has_prefix ("localhost") || text.has_prefix ("[")))
                return (text.has_prefix ("localhost") || text.has_prefix ("127.") ? "http://" : "https://") + text;
            return search.replace ("%s", Uri.escape_string (text, null, false));
        }
        public static Uri web_uri (string url) throws Error {
            var uri = Uri.parse (url, UriFlags.NONE);
            if ((uri.get_scheme () != "https" && uri.get_scheme () != "http") || uri.get_host () == null || uri.get_userinfo () != null)
                throw new BrowserError.INVALID_URL ("An HTTP(S) URL without embedded credentials is required");
            return uri;
        }
        public static string origin (string url) throws Error {
            var u = web_uri (url);
            int port = u.get_port ();
            bool standard = port == -1 || (u.get_scheme () == "https" && port == 443) || (u.get_scheme () == "http" && port == 80);
            var host = u.get_host ().ascii_down ();
            if (host.contains (":")) host = "[" + host + "]";
            return "%s://%s%s".printf (u.get_scheme (), host, standard ? "" : ":%d".printf (port));
        }
    }
}
