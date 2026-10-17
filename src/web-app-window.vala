namespace MajorisBrowser {
    public class WebAppWindow : Adw.ApplicationWindow {
        private BrowserSurface surface;
        private delegate void ExternalNavigation (string target);
        public WebAppWindow (Application app,WebApp metadata) {
            Object (application: app,title: metadata.name,default_width:1100,default_height:760);
            var layout = new Adw.ToolbarView ();
            var header = new Adw.HeaderBar (); header.decoration_layout = ":minimize,maximize,close";
            layout.add_top_bar (header);
            try {
                surface = new OffscreenBrowserSurface (app.paths.webapp_context (metadata.id),false,metadata.start_url,metadata.scope);
                layout.content=surface; content=layout; EngineDialogs.attach (surface,this);
                var policy = new WebAppNavigationPolicy (metadata.scope);
                var auth = new AuthenticationPolicy (metadata.scope);
                bool auth_prompt=false;
                ExternalNavigation external = (target) => {
                    if(auth.is_candidate(target)){
                        if(auth_prompt)return;auth_prompt=true;
                        string origin;try{origin=UrlResolver.origin(target);}catch(Error e){return;}
                        var dialog=new Adw.AlertDialog(_("Continue Signing In?"),_("This application is requesting a temporary sign-in flow at:")+"\n"+origin);
                        dialog.add_response("cancel",_("Cancel"));dialog.add_response("continue",_("Continue"));dialog.default_response="cancel";dialog.close_response="cancel";
                        dialog.response.connect((id)=>{auth_prompt=false;if(id=="continue"){surface.engine.allow_auth(target);surface.navigate(target);}});dialog.present(this);
                    }else app.open_external(target);
                };
                surface.changed.connect ((kind,value) => {
                    if (kind == "title") title=value;
                    if (kind == "external") external (value);
                    if (kind == "popup") {
                        if (policy.classify (value) == NavigationDecision.APP_SCOPE) surface.navigate (value);
                        else external (value);
                    }
                    if (kind == "error" || kind == "crashed") EngineDialogs.show_error (this,value);
                });
                close_request.connect (() => { surface.close (); return false; });
                if(Environment.get_variable("MAJORIS_UI_SMOKE")=="1")Timeout.add(2500,()=>{assert(surface.has_frame);return Source.REMOVE;});
            } catch (Error e) { EngineDialogs.show_error (this,e.message); }
        }
    }
}
