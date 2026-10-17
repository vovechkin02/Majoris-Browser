namespace MajorisBrowser {
    public enum NavigationDecision { APP_SCOPE, AUTHENTICATION_FLOW, EXTERNAL }
    public class WebAppNavigationPolicy : Object {
        private string scope;
        private string origin;
        public WebAppNavigationPolicy (string scope) throws Error { this.scope = scope; origin = UrlResolver.origin (scope); }
        public NavigationDecision classify (string url) {
            try {
                var u = UrlResolver.web_uri (url);
                var s = UrlResolver.web_uri (scope);
                string path = u.get_path ();
                string base_path = s.get_path ();
                bool in_path = path == base_path || path.has_prefix (base_path.has_suffix ("/") ? base_path : base_path + "/");
                if (UrlResolver.origin (url) == origin && in_path) return NavigationDecision.APP_SCOPE;
            } catch (Error e) { }
            return NavigationDecision.EXTERNAL;
        }
    }
}
