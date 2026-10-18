namespace MajorisBrowser {
    public class WebAppWindow : Adw.ApplicationWindow {
        private BrowserSurface surface;
        private delegate void ExternalNavigation (string target,bool intermediate);
        public WebAppWindow (Application app,WebApp metadata,MajorisCef.View? engine=null,string? initial_url=null) {
            Object (application: app,title: metadata.name,default_width:1100,default_height:760);
            icon_name=metadata.application_id;
            var layout = new Adw.ToolbarView ();
            var header = new Adw.HeaderBar (); header.decoration_layout = ":minimize,maximize,close";
            layout.add_top_bar (header);
            try {
                surface = engine==null?new OffscreenBrowserSurface (app.paths.webapp_context (metadata.id),false,initial_url??metadata.start_url,metadata.scope,app.permissions.serialized()):new OffscreenBrowserSurface.with_engine(engine);
                app.permissions.attach(surface.engine);
                surface.engine.popup.connect((child,background,url,new_window)=>{
                    try{if(new WebAppNavigationPolicy(metadata.scope).classify(url)==NavigationDecision.APP_SCOPE || child.is_auth_popup())new WebAppWindow(app,metadata,child).present();else{child.close();app.open_external(url);}}catch(Error e){child.close();EngineDialogs.show_error(this,e.message);}
                });
                layout.content=surface; content=layout; EngineDialogs.attach (surface,this);
                new CredentialController(app,surface,metadata.id);
                PageActions.attach(surface);
                new AddressController(app,surface);
                foreach(string name in new string[]{"reload","back","forward","print","save-pdf","save-page","devtools"}){string command=name;var action=new SimpleAction(name,null);action.activate.connect(()=>surface.engine.command(command));add_action(action);}
                app.set_accels_for_action("win.devtools",{"F12","<Control><Shift>i"});app.set_accels_for_action("win.reload",{"<Control>r"});app.set_accels_for_action("win.print",{"<Control>p"});app.set_accels_for_action("win.cancel-sign-in",{"Escape"});
                var downloads=new SimpleAction("downloads",null);downloads.activate.connect(()=>new DownloadsDialog(app,surface.engine).present(this));add_action(downloads);
                var passwords=new SimpleAction("passwords",null);passwords.activate.connect(()=>new CredentialManager(metadata.id,surface.engine).present(this));add_action(passwords);
                var permissions=new SimpleAction("permissions",null);permissions.activate.connect(()=>new PolicyDialog(app,metadata.id).present(this));add_action(permissions);
                var cancel_auth=new SimpleAction("cancel-sign-in",null);cancel_auth.activate.connect(()=>{surface.engine.command("auth-cancel");surface.navigate(metadata.start_url);});add_action(cancel_auth);
                var policy = new WebAppNavigationPolicy (metadata.scope);
                var auth = new AuthenticationPolicy (metadata.scope);
                bool auth_prompt=false;
                ExternalNavigation external = (target,intermediate) => {
                    if(auth.is_candidate(target) || intermediate){
                        if(auth_prompt)return;
                        string origin;try{origin=UrlResolver.origin(target);}catch(Error e){return;}
                        auth_prompt=true;
                        var dialog=new Adw.AlertDialog(_("Continue Signing In?"),_("This application is requesting a temporary sign-in flow at:")+"\n"+origin);
                        dialog.add_response("cancel",_("Cancel"));dialog.add_response("continue",_("Continue"));dialog.default_response="cancel";dialog.close_response="cancel";
                        dialog.response.connect((id)=>{auth_prompt=false;if(surface.closed)return;if(id=="continue"){surface.engine.allow_auth(target);surface.navigate(target);}else{surface.engine.command("auth-cancel");if(engine!=null)close();}});dialog.present(this);
                    }else app.open_external(target);
                };
                surface.changed.connect ((kind,value) => {
                    if (kind == "title") title=value;
                    if (kind == "external" || kind=="auth-intermediate") external (value,kind=="auth-intermediate");
                    if(kind=="external-untrusted")app.open_external(value);
                    if (kind == "popup" || kind=="popup-background" || kind=="popup-window") {
                        if (policy.classify (value) == NavigationDecision.APP_SCOPE || auth.is_candidate(value))new WebAppWindow(app,metadata,null,value).present();
                        else app.open_external(value);
                    }
                    if (kind == "download") app.downloads.update(surface.engine,value,false);
                    if(kind=="context")context_menu(app,metadata,value);
                    if(kind=="closed")close();
                });
                bool close_ready=false,close_pending=false;
                close_request.connect (() => {
                    if(close_ready)return false;
                    if(!close_pending){close_pending=true;surface.request_close.begin((object,result)=>{
                        close_pending=false;close_ready=surface.request_close.end(result);if(close_ready)close();
                    });}
                    return true;
                });
                if(Environment.get_variable("MAJORIS_UI_SMOKE")=="1")Timeout.add(2500,()=>{assert(surface.has_frame);return Source.REMOVE;});
            } catch (Error e) { EngineDialogs.show_error (this,e.message); }
        }
        private void context_menu(Application app,WebApp metadata,string text){PageContextMenu.show(app,surface,text,(url,new_window)=>{try{if(new WebAppNavigationPolicy(metadata.scope).classify(url)==NavigationDecision.APP_SCOPE)new WebAppWindow(app,metadata,null,url).present();else app.open_external(url);}catch(Error e){EngineDialogs.show_error(this,e.message);}});}
    }
}
