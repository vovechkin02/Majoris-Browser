namespace MajorisBrowser {
    public enum NavigationDecision { APP_SCOPE, AUTHENTICATION_FLOW, EXTERNAL }
    public class WebAppNavigationPolicy : Object {
        private string scope;
        private string origin;
        public static string normalized_path(string url) throws Error {
            var u=Uri.parse(Uri.resolve_relative(url,"",UriFlags.ENCODED_PATH),UriFlags.ENCODED_PATH);
            string path=u.get_path(),lower=path.ascii_down();
            if(path.contains("\\") || lower.contains("%2f") || lower.contains("%5c") || lower.contains("%2e"))throw new BrowserError.INVALID_URL("Ambiguous encoded application path");
            return path==""?"/":path;
        }
        public WebAppNavigationPolicy (string scope) throws Error {var u=UrlResolver.web_uri(scope);if(u.get_query()!=null || u.get_fragment()!=null)throw new BrowserError.INVALID_APP("Application scope cannot contain a query or fragment");this.scope = scope; origin = UrlResolver.origin (scope);normalized_path(scope);}
        public NavigationDecision classify (string url) {
            try {
                var u = UrlResolver.web_uri (url);
                var s = UrlResolver.web_uri (scope);
                string path = normalized_path(url);
                string base_path = normalized_path(scope);
                bool in_path = path == base_path || path.has_prefix (base_path.has_suffix ("/") ? base_path : base_path + "/");
                if (UrlResolver.origin (url) == origin && in_path) return NavigationDecision.APP_SCOPE;
            } catch (Error e) { }
            return NavigationDecision.EXTERNAL;
        }
    }
}
