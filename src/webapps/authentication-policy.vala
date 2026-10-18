namespace MajorisBrowser {
    // A candidate is not authorization: the GTK host must obtain consent before
    // temporarily granting this exact provider origin to an app-owned view.
    public class AuthenticationPolicy : Object {
        private WebAppNavigationPolicy app_policy;
        public AuthenticationPolicy (string scope) throws Error { app_policy=new WebAppNavigationPolicy(scope); }
        public bool is_candidate (string target) {
            try {
                var uri=UrlResolver.web_uri(target);
                if(target.length>16384 || uri.get_scheme()!="https" || uri.get_query()==null)return false;
                var query=Uri.parse_params(uri.get_query());
                var seen=new Gee.HashSet<string>();foreach(string pair in uri.get_query().split("&")){string? key=Uri.unescape_string(pair.split("=")[0]);if(key==null || seen.contains(key))return false;seen.add(key);}
                string host=uri.get_host().ascii_down();
                if(host=="accounts.google.com" && query.contains("continue"))
                    {var back=UrlResolver.web_uri(query["continue"]);return back.get_fragment()==null && query["continue"].length<=4096 && app_policy.classify(query["continue"])==NavigationDecision.APP_SCOPE;}
                if(!query.contains("redirect_uri") || !query.contains("state") || !query.contains("client_id"))return false;
                bool recognized=host=="login.microsoftonline.com" || host=="accounts.spotify.com" || host=="accounts.google.com";
                if(!recognized && (!query.contains("response_type") || query["response_type"]!="code"))return false;
                var back=UrlResolver.web_uri(query["redirect_uri"]);return back.get_fragment()==null && query["state"].length>=16 && query["state"].length<=4096 && query["client_id"]!="" && app_policy.classify(query["redirect_uri"])==NavigationDecision.APP_SCOPE;
            }catch(Error e){return false;}
        }
    }
}
