namespace MajorisBrowser {
    public class Application : Adw.Application {
        public ProfilePaths paths;
        public Settings preferences;
        public StoreWorker storage;
        public WebApp? webapp;
        public bool private_requested;
        private bool runtime_started;
        private bool clear_on_exit;
        public Application (ProfilePaths paths,WebApp? app,bool private_requested) {
            Object (application_id: app != null ? app.application_id : "com.majoris.browser", flags: ApplicationFlags.HANDLES_OPEN);
            this.paths=paths; this.webapp=app; this.private_requested=private_requested;
            preferences = new Settings ("com.majoris.browser"); storage = new StoreWorker (paths.browser_store);
        }
        protected override void startup () {
            base.startup ();
            var action = new SimpleAction ("new-window",null); action.activate.connect (() => new BrowserWindow (this,false).present ()); add_action (action);
            action = new SimpleAction ("private-window",null); action.activate.connect (() => new BrowserWindow (this,true).present ()); add_action (action);
            set_accels_for_action ("app.new-window", {"<Control>n"}); set_accels_for_action ("app.private-window", {"<Control><Shift>n"});
        }
        private bool ensure_runtime () {
            if (runtime_started) return true;
            try {
                string profile = webapp == null ? paths.browser_context : paths.webapp_context (webapp.id);
                DirUtils.create_with_parents (profile,0700);
                string helper = Environment.get_variable ("MAJORIS_CEF_HELPER") ?? Config.CEF_HELPER;
                string resources = Environment.get_variable ("MAJORIS_CEF_RESOURCES") ?? Config.CEF_RESOURCES;
                MajorisCef.initialize (profile,helper,resources); runtime_started=true; return true;
            } catch (Error e) { critical ("CEF: %s",e.message); return false; }
        }
        protected override void activate () {
            if (!ensure_runtime ()) { quit (); return; }
            if (active_window != null) { active_window.present (); return; }
            if (webapp != null) {
                var window=new WebAppWindow (this,webapp);window.present ();
                if(Environment.get_variable("MAJORIS_UI_SMOKE")=="1")Timeout.add_seconds(3,()=>{window.close();return Source.REMOVE;});
            } else {
                var window=new BrowserWindow (this,private_requested);window.present ();
                if(Environment.get_variable("MAJORIS_UI_SMOKE")=="1")window.smoke_test ();
            }
        }
        protected override void open (File[] files,string hint) {
            if (!ensure_runtime ()) return;
            if (webapp != null) { activate (); return; }
            BrowserWindow window = active_window as BrowserWindow ?? new BrowserWindow (this,false,false);
            foreach (var file in files) window.add_tab (file.get_uri ());
            window.present ();
        }
        protected override void shutdown () {
            storage.stop (); if (runtime_started) MajorisCef.shutdown ();
            if(clear_on_exit){try{MajorisCef.clear_profile(paths.browser_context);}catch(Error e){critical("Browser profile clearing: %s",e.message);}}
            base.shutdown ();
        }
        public void clear_browser_profile () {
            if(webapp!=null)return;
            clear_on_exit=true;
            var windows=new Gee.ArrayList<Gtk.Window>();foreach(var window in get_windows())windows.add(window);
            foreach(var window in windows){
                var host=window as Adw.ApplicationWindow;
                if(host!=null && host.visible_dialog!=null)host.visible_dialog.force_close();
                window.close();
            }
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
        var application=new MajorisBrowser.Application (paths,app,priv);
        application.register (null);
        if(application.is_remote && priv){application.activate_action("private-window",null);application.storage.stop();return 0;}
        return application.run (remaining);
    } catch (Error e) { stderr.printf ("Browser: %s\n",e.message); return 1; }
}
