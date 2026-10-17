namespace MajorisBrowser {
    public class WebAppWindow : Adw.ApplicationWindow {
        private BrowserSurface surface;
        private delegate void ExternalNavigation (string target);
        public WebAppWindow (Application app,WebApp metadata,MajorisCef.View? engine=null) {
            Object (application: app,title: metadata.name,default_width:1100,default_height:760);
            icon_name=metadata.application_id;
            var layout = new Adw.ToolbarView ();
            var header = new Adw.HeaderBar (); header.decoration_layout = ":minimize,maximize,close";
            var menu=new Menu();foreach(string action in new string[]{"reload","back","forward","downloads","passwords","permissions","print","save-pdf","save-page","devtools"})menu.append(action,"win."+action);var menu_button=new Gtk.MenuButton();menu_button.icon_name="open-menu-symbolic";menu_button.menu_model=menu;header.pack_end(menu_button);
            menu.append(_("Cancel Sign-In"),"win.cancel-sign-in");
            layout.add_top_bar (header);
            try {
                surface = engine==null?new OffscreenBrowserSurface (app.paths.webapp_context (metadata.id),false,metadata.start_url,metadata.scope,app.permissions.serialized()):new OffscreenBrowserSurface.with_engine(engine);
                app.permissions.attach(surface.engine);
                surface.engine.popup.connect((child,background,url,new_window)=>{
                    try{if(new WebAppNavigationPolicy(metadata.scope).classify(url)==NavigationDecision.APP_SCOPE || new AuthenticationPolicy(metadata.scope).is_candidate(url))new WebAppWindow(app,metadata,child).present();else{child.close();app.open_external(url);}}catch(Error e){child.close();EngineDialogs.show_error(this,e.message);}
                });
                layout.content=surface; content=layout; EngineDialogs.attach (surface,this);
                new CredentialController(app,surface,metadata.id);
                PageActions.attach(surface);
                foreach(string name in new string[]{"reload","back","forward","print","save-pdf","save-page","devtools"}){string command=name;var action=new SimpleAction(name,null);action.activate.connect(()=>surface.engine.command(command));add_action(action);}
                var downloads=new SimpleAction("downloads",null);downloads.activate.connect(()=>new DownloadsDialog(app,surface.engine).present(this));add_action(downloads);
                var passwords=new SimpleAction("passwords",null);passwords.activate.connect(()=>new CredentialManager(metadata.id,surface.engine).present(this));add_action(passwords);
                var permissions=new SimpleAction("permissions",null);permissions.activate.connect(()=>new PolicyDialog(app,metadata.id).present(this));add_action(permissions);
                var cancel_auth=new SimpleAction("cancel-sign-in",null);cancel_auth.activate.connect(()=>{surface.engine.command("auth-cancel");surface.navigate(metadata.start_url);});add_action(cancel_auth);
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
                    if (kind == "popup" || kind=="popup-background" || kind=="popup-window") {
                        if (policy.classify (value) == NavigationDecision.APP_SCOPE) surface.navigate (value);
                        else external (value);
                    }
                    if (kind == "download") app.downloads.update(surface.engine,value,false);
                    if(kind=="context")context_menu(app,value);
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
        private void context_menu(Application app,string text){
            try{var parser=new Json.Parser();parser.load_from_data(text);var data=parser.get_root().get_object();var menu=new Menu();var actions=new SimpleActionGroup();
                foreach(string name in new string[]{"back","forward","reload","copy","cut","paste","select-all","print","devtools"}){if((name=="cut" || name=="paste") && !data.get_boolean_member("editable"))continue;string command=name;var action=new SimpleAction(name,null);action.activate.connect(()=>surface.engine.command(command));actions.add_action(action);menu.append(name,"page."+name);}
                string link=data.get_string_member("link");if(link!=""){var open=new SimpleAction("open-browser",null);open.activate.connect(()=>app.open_external(link));actions.add_action(open);menu.append(_("Open Link in Browser"),"page.open-browser");var copy=new SimpleAction("copy-link",null);copy.activate.connect(()=>get_clipboard().set_text(link));actions.add_action(copy);menu.append(_("Copy Link"),"page.copy-link");}
                surface.insert_action_group("page",actions);var pop=new Gtk.PopoverMenu.from_model(menu);pop.set_parent(surface);Gdk.Rectangle rect={(int)data.get_int_member("x"),(int)data.get_int_member("y"),1,1};pop.pointing_to=rect;pop.closed.connect(()=>pop.unparent());pop.popup();
            }catch(Error e){EngineDialogs.show_error(this,e.message);}
        }
    }
}
