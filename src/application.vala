namespace MajorisBrowser {
    public class Application : Adw.Application {
        public ProfilePaths paths;
        public Settings preferences;
        public StoreWorker storage;
        public SessionService sessions;
        public PermissionService permissions;
        public DownloadService downloads;
        public ThreatProtectionService threats=new ThreatProtectionService();
        public signal void bookmarks_changed();
        private bool session_started;
        public WebApp? webapp;
        public bool private_requested;
        private bool runtime_started;
        private ExitOperation exit_operation=new ExitOperation();
        public Application (ProfilePaths paths,WebApp? app,bool private_requested) throws Error {
            Object (application_id: app != null ? app.application_id : "com.majoris.browser", flags: ApplicationFlags.HANDLES_OPEN);
            this.paths=paths; this.webapp=app; this.private_requested=private_requested;
            preferences = new Settings ("com.majoris.browser"); storage = new StoreWorker (paths.browser_store);
            bool managed=preferences.get_boolean("web-risk-managed");string endpoint=preferences.get_string("managed-threat-endpoint");bool consent=WebRiskProvider.consent_matches(preferences.get_boolean("web-risk-consent"),managed,endpoint,preferences.get_string("web-risk-consent-target"));
            try{threats=new ThreatProtectionService(managed?new WebRiskProvider.managed_service(consent,endpoint):new WebRiskProvider(consent));}catch(Error e){ThreatProvider failed=consent?(ThreatProvider)new UnavailableThreatProvider():new UnconfiguredThreatProvider();threats=new ThreatProtectionService(failed);}
            storage.operation_failed.connect((message)=>{if(active_window!=null)EngineDialogs.show_error(active_window,message);});
            sessions=new SessionService(this);
            permissions=new PermissionService(storage,app==null?"browser":app.id);
            permissions.policies_changed.connect((profile)=>{if(ProfilePaths.valid_id(profile) && (webapp==null || webapp.id!=profile))notify_permission_change.begin(profile);});
            DownloadSecurityProvider scanner=preferences.get_string("download-scanner-socket")==""?(DownloadSecurityProvider)new NoDownloadScanner():new ClamdDownloadScanner(preferences.get_string("download-scanner-socket"),preferences.get_uint("download-scanner-max-mib"));downloads=new DownloadService(this,scanner);
            downloads.threat_detected.connect((record)=>{if(active_window!=null)EngineDialogs.show_error(active_window,_("Known threat detected in downloaded file: %s. Opening is blocked. The file has been retained.").printf(record.filename));});
        }
        protected override void startup () {
            base.startup ();
            notify["active-window"].connect(()=>sessions.changed());
            var action = new SimpleAction ("new-window",null); action.activate.connect (() => {if(webapp==null)new BrowserWindow(this,false).present();else new WebAppWindow(this,webapp).present();}); add_action (action);
            action = new SimpleAction ("private-window",null);action.set_enabled(webapp==null);action.activate.connect (() => new BrowserWindow (this,true).present ()); add_action (action);
            set_accels_for_action ("app.new-window", {"<Control>n"}); set_accels_for_action ("app.private-window", {"<Control><Shift>n"});
            action=new SimpleAction("quit",null);action.activate.connect(()=>request_exit.begin(false));add_action(action);set_accels_for_action("app.quit",{"<Control>q"});
            action=new SimpleAction("reload-permissions",null);action.activate.connect(()=>permissions.reload());add_action(action);
        }
        private bool ensure_runtime () {
            if (runtime_started) return true;
            try {
                string profile = webapp == null ? paths.browser_context : paths.webapp_context (webapp.id);
                DirUtils.create_with_parents (profile,0700);
                string helper = Environment.get_variable ("MAJORIS_CEF_HELPER") ?? Config.CEF_HELPER;
                string resources = Environment.get_variable ("MAJORIS_CEF_RESOURCES") ?? Config.CEF_RESOURCES;
                Environment.set_variable("CHROME_DESKTOP",webapp==null?"com.majoris.browser.desktop":webapp.desktop_name,true);
                Environment.set_variable("MAJORIS_CEF_DISPLAY_NAME",webapp==null?"Majoris Browser":webapp.name,true);
                if(!preferences.get_boolean("hardware-acceleration"))Environment.set_variable("MAJORIS_CEF_DISABLE_GPU","1",true);else Environment.unset_variable("MAJORIS_CEF_DISABLE_GPU");
                var display=Gdk.Display.get_default();string backend=display!=null?display.get_type().name():"";
                if(!MajorisCef.set_display_backend(backend=="GdkWaylandDisplay"?"wayland":"x11"))throw new IOError.FAILED("Cannot select the Chromium display backend");
                MajorisCef.initialize (profile,helper,resources); runtime_started=true; return true;
            } catch (Error e) { critical ("CEF: %s",e.message); return false; }
        }
        private async void notify_permission_change(string profile){
            try{var bus=yield Bus.get(BusType.SESSION,null);var args=new VariantBuilder(new VariantType("av"));var platform=new VariantBuilder(new VariantType("a{sv}"));yield bus.call("com.majoris.browser.WebApp."+profile,"/com/majoris/browser/WebApp/"+profile,"org.gtk.Actions","Activate",new Variant("(s@av@a{sv})","reload-permissions",args.end(),platform.end()),null,DBusCallFlags.NO_AUTO_START,1000,null);}catch(Error e){/* A stopped app loads policy on its next launch. */}
        }
        protected override void activate () {
            cancel_exit();
            if (!ensure_runtime ()) { quit (); return; }
            if (active_window != null) { active_window.present (); return; }
            if (webapp != null) {
                var window=new WebAppWindow (this,webapp);window.present ();
                if(Environment.get_variable("MAJORIS_UI_SMOKE")=="1")Timeout.add_seconds(Environment.get_variable("MAJORIS_APP_SMOKE_LIFETIME")=="12"?12:3,()=>{window.close();return Source.REMOVE;});
            } else {
                if(!session_started && !private_requested && Environment.get_variable("MAJORIS_UI_SMOKE")!="1"){
                    session_started=true;hold();
                    storage.run((store)=>{
                        string? saved=store.snapshot_state();bool clean=store.snapshot_clean();
                        if(saved!=null)store.snapshot(GLib.get_real_time(),saved,false);
                        Idle.add(()=>{
                            if(saved!=null && preferences.get_string("startup")=="restore")sessions.restore(saved);
                            else {
                                var window=new BrowserWindow(this,false);window.present();
                                if(saved!=null && !clean){var dialog=new Adw.AlertDialog(_("Restore Browser Session?"),_("Browser did not shut down cleanly."));dialog.add_response("new",_("Start Fresh"));dialog.add_response("restore",_("Restore"));dialog.response.connect((id)=>{if(id=="restore"){sessions.restoring=true;window.close();sessions.restoring=false;sessions.restore(saved);}});dialog.present(window);}
                            }
                            release();return Source.REMOVE;
                        });
                    });return;
                }
                var window=new BrowserWindow (this,private_requested);window.present ();
                if(Environment.get_variable("MAJORIS_UI_SMOKE")=="1")window.smoke_test ();
            }
        }
        protected override void open (File[] files,string hint) {
            cancel_exit();
            if (!ensure_runtime ()) return;
            if (webapp != null) { activate (); return; }
            BrowserWindow window = active_window as BrowserWindow ?? new BrowserWindow (this,false,false);
            foreach (var file in files) window.add_tab (file.get_uri ());
            window.present ();
        }
        protected override void shutdown () {
            downloads.stop();
            sessions.stop();
            storage.stop (); if (runtime_started) {MajorisCef.shutdown ();runtime_started=false;}
            if(exit_operation.finish(!runtime_started)){try{MajorisCef.clear_profile(paths.browser_context);}catch(Error e){critical("Browser profile clearing: %s",e.message);}}
            base.shutdown ();
        }
        public void clear_browser_profile () {
            if(webapp!=null)return;
            request_exit.begin(true);
        }
        public void cancel_exit(){
            if(exit_operation.phase==ExitPhase.PENDING || exit_operation.phase==ExitPhase.APPROVED){exit_operation.cancel();sessions.closing_all=false;}
        }
        private async void request_exit(bool clear){
            if(webapp!=null){foreach(var window in get_windows())window.close();return;}
            if(!exit_operation.begin(clear))return;
            uint64 generation=exit_operation.generation;
            hold();sessions.begin_shutdown();
            var windows=new Gee.ArrayList<Gtk.Window>();foreach(var window in get_windows())windows.add(window);
            foreach(var window in windows){
                var browser=window as BrowserWindow;
                bool accepted=browser==null || (yield browser.close_for_exit());
                if(generation!=exit_operation.generation){release();return;}
                if(!accepted){cancel_exit();release();return;}
                if(exit_operation.phase!=ExitPhase.PENDING){release();return;}
            }
            foreach(var window in get_windows()){
                var browser=window as BrowserWindow;
                if(browser!=null && !browser.closing){cancel_exit();release();return;}
            }
            foreach(var window in windows)if(!(window is BrowserWindow))window.close();
            exit_operation.approve(true);release();
        }
        public void open_external (string url) {
            try {
                UrlResolver.web_uri (url);
                new Subprocess.newv ({"majoris-browser",url},SubprocessFlags.NONE);
            } catch (Error e) { warning ("WebApp external navigation: %s",e.message); }
        }
    }
}
int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL,""); Intl.bindtextdomain ("majoris-browser",Config.LOCALEDIR); Intl.textdomain ("majoris-browser");
    try {
        var paths = new MajorisBrowser.ProfilePaths (); paths.prepare ();
        MajorisBrowser.WebApp? app = null; bool priv = false;
        string[] remaining = {args[0]};
        foreach (string arg in args[1:args.length]) {
            if (arg.has_prefix ("--app=")) {
                string id=arg.substring (6);
                if (!MajorisBrowser.ProfilePaths.valid_id (id)) throw new MajorisBrowser.BrowserError.INVALID_APP ("Invalid application ID");
                var store = new MajorisBrowser.Store (paths.browser_store); app=store.get_app (id);
                if (app == null) throw new MajorisBrowser.BrowserError.INVALID_APP ("Application is not installed");
            } else if (arg == "--private") priv=true;
            else remaining += arg;
        }
        // Set the GTK/X11 program identity before GTK initializes. An app must
        // not inherit the Browser executable's WM_CLASS or display name.
        Environment.set_prgname(app!=null?app.application_id:"com.majoris.browser");
        Environment.set_application_name(app!=null?app.name:_("Majoris Browser"));
        var application=new MajorisBrowser.Application (paths,app,priv);
        application.register (null);
        if(application.is_remote && priv){application.activate_action("private-window",null);application.storage.stop();return 0;}
        return application.run (remaining);
    } catch (Error e) { stderr.printf ("Browser: %s\n",e.message); return 1; }
}
