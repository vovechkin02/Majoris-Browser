namespace MajorisBrowser {
    public class BrowserWindow : Adw.ApplicationWindow {
        private Application app;
        private bool is_private;
        private Adw.TabView tabs = new Adw.TabView ();
        private Gtk.Entry address = new Gtk.Entry ();
        private Gtk.Button back;
        private Gtk.Button forward;
        private Gtk.Button reload;
        private Gee.ArrayList<TabState> closed = new Gee.ArrayList<TabState> ();
        private uint session_save=0;
        private Gee.HashMap<BrowserSurface,string> manifest_requests=new Gee.HashMap<BrowserSurface,string>();
        private bool window_closing=false;
        private Gtk.SearchEntry find = new Gtk.SearchEntry ();
        private Gtk.Revealer find_bar = new Gtk.Revealer ();
        private string window_id = Uuid.string_random ();
        private BrowserSurface? selected { get { return tabs.selected_page == null ? null : tabs.selected_page.child as BrowserSurface; } }
        public BrowserWindow (Application app,bool is_private,bool initial_tab = true) {
            Object (application:app,title:is_private ? _("Private Browser") : _("Browser"),default_width:1200,default_height:800);
            this.app=app; this.is_private=is_private;
            var layout = new Adw.ToolbarView ();
            var header = new Adw.HeaderBar (); header.decoration_layout=":minimize,maximize,close";
            header.title_widget = new Gtk.Label (is_private ? _("Private Browsing") : _("Browser"));
            var plus = new Gtk.Button.from_icon_name ("list-add-symbolic"); plus.tooltip_text=_("New Tab"); plus.clicked.connect (() => add_tab ("about:blank")); header.pack_start (plus);
            var menu = new Menu ();
            string[,] entries = {{"New Tab","new-tab"},{"New Window","new-window"},{"Private Window","private"},{"Duplicate Tab","duplicate"},{"Pin / Unpin Tab","pin"},{"Reopen Closed Tab","reopen"},{"Bookmarks","bookmarks"},{"History","history"},{"Downloads","downloads"},{"Find in Page","find"},{"Install as App…","install-app"},{"Settings","settings"},{"Task Manager","tasks"},{"Developer Tools","devtools"},{"About Browser","about"}};
            for (int i=0;i<entries.length[0];i++) menu.append (_(entries[i,0]),"win."+entries[i,1]);
            var menu_button = new Gtk.MenuButton (); menu_button.icon_name="open-menu-symbolic"; menu_button.menu_model=menu; header.pack_end (menu_button); layout.add_top_bar (header);
            var bar = new Adw.TabBar (); bar.view=tabs; layout.add_top_bar (bar);
            var nav = new Gtk.Box (Gtk.Orientation.HORIZONTAL,6); nav.margin_start=8;nav.margin_end=8;nav.margin_top=6;nav.margin_bottom=6;
            back=button ("go-previous-symbolic",_("Back"),() => command ("back")); nav.append (back);
            forward=button ("go-next-symbolic",_("Forward"),() => command ("forward")); nav.append (forward);
            reload=button ("view-refresh-symbolic",_("Reload"),() => command ("reload")); nav.append (reload);
            nav.append (button ("channel-secure-symbolic",_("Site Information"),site_info));
            address.hexpand=true; address.placeholder_text=_("Search or enter address"); address.activate.connect (() => { if(selected!=null) selected.navigate (UrlResolver.resolve (address.text,app.preferences.get_string ("search-template"))); }); nav.append (address);
            nav.append (button ("star-new-symbolic",_("Bookmark Page"),bookmark)); layout.add_top_bar (nav);
            var body = new Gtk.Box (Gtk.Orientation.VERTICAL,0);
            find_bar.child=find; find.search_changed.connect (() => command ("find:"+find.text)); body.append (find_bar); body.append (tabs); tabs.vexpand=true;
            layout.content=body; content=layout;
            tabs.notify["selected-page"].connect (() => { if(selected!=null)address.text=selected.url; });
            tabs.close_page.connect ((page) => {
                var s=page.child as BrowserSurface; closed.add(new TabState(s.url,page.pinned));if(closed.size>25)closed.remove_at(0);s.close (); tabs.close_page_finish (page,true);schedule_session();
                if(tabs.n_pages==0) close (); return true;
            });
            setup_actions ();
            close_request.connect (() => { window_closing=true;if(session_save!=0){Source.remove(session_save);session_save=0;}save_session (); for(int i=0;i<tabs.n_pages;i++){var surface=tabs.get_nth_page(i).child as BrowserSurface;if(surface!=null)surface.close();}return false; });
            if(initial_tab) {
                if(!is_private && app.preferences.get_string ("startup") == "restore") restore_session ();
                else add_tab (app.preferences.get_string ("homepage"));
            }
        }
        private Gtk.Button button (string icon,string tooltip,owned ActionFunc callback) {
            var b=new Gtk.Button.from_icon_name(icon); b.tooltip_text=tooltip;b.clicked.connect (() => callback ());return b;
        }
        private delegate void ActionFunc ();
        private void action (string name,string[] shortcuts,owned ActionFunc callback) {
            var a=new SimpleAction(name,null);a.activate.connect (() => callback ());add_action(a);
            if(shortcuts.length>0)app.set_accels_for_action("win."+name,shortcuts);
        }
        private void setup_actions () {
            action("new-tab",{"<Control>t"},() => add_tab("about:blank"));
            action("new-window",{},() => new BrowserWindow(app,false).present());
            action("private",{},() => new BrowserWindow(app,true).present());
            action("focus-address",{"<Control>l"},() => {address.grab_focus();address.select_region(0,-1);});
            action("close-tab",{"<Control>w"},() => {if(tabs.selected_page!=null)tabs.close_page(tabs.selected_page);});
            action("reopen",{"<Control><Shift>t"},() => {if(closed.size>0){var state=closed.remove_at(closed.size-1);add_tab(state.url);tabs.set_page_pinned(tabs.selected_page,state.pinned);}});
            action("duplicate",{},() => {if(selected!=null)add_tab(selected.url);});
            action("pin",{},() => {if(tabs.selected_page!=null)tabs.set_page_pinned(tabs.selected_page,!tabs.selected_page.pinned);});
            action("next-tab",{"<Control>Tab"},() => tabs.select_next_page());
            action("previous-tab",{"<Control><Shift>Tab"},() => tabs.select_previous_page());
            action("find",{"<Control>f"},() => {find_bar.reveal_child=!find_bar.reveal_child;if(find_bar.reveal_child)find.grab_focus();else command("find-stop");});
            action("bookmark",{"<Control>d"},bookmark);
            action("bookmarks",{},() => show_records(true));
            action("history",{"<Control>h"},() => show_records(false));
            action("downloads",{"<Control>j"},() => show_downloads());
            action("settings",{},() => new PreferencesWindow(app).present(this));
            action("install-app",{},install_app);
            action("tasks",{"<Shift>Escape"},() => {if(selected!=null)new TaskManager(app,selected.engine).present();});
            action("fullscreen",{"F11"},() => {if(fullscreened)unfullscreen();else fullscreen();});
            action("back",{"<Alt>Left"},() => command("back"));
            action("forward",{"<Alt>Right"},() => command("forward"));
            action("reload",{"<Control>r"},() => command("reload"));
            action("hard-reload",{"<Control><Shift>r"},() => command("hard-reload"));
            action("zoom-in",{"<Control>plus","<Control>equal"},() => command("zoom-in"));
            action("zoom-out",{"<Control>minus"},() => command("zoom-out"));
            action("zoom-reset",{"<Control>0"},() => command("zoom-reset"));
            action("devtools",{"F12","<Control><Shift>i"},() => command("devtools"));
            action("print",{"<Control>p"},() => command("print"));
            action("about",{},() => {
                var about=new Adw.AboutDialog();about.application_name="Majoris Browser";about.application_icon="com.majoris.browser";about.version=Config.VERSION;about.developer_name="Majoris";about.comments="CEF "+MajorisCef.version();about.license_type=Gtk.License.GPL_3_0;about.present(this);
            });
        }
        private void command (string name) { if(selected!=null)selected.engine.command(name); }
        public void add_tab (string url) {
            var surface=new OffscreenBrowserSurface(is_private?window_id:app.paths.browser_context,is_private,url);
            var page=tabs.append(surface);page.title=_("New Tab");tabs.selected_page=page;
            EngineDialogs.attach(surface,this);
            surface.changed.connect ((kind,value) => {
                if(window_closing)return;
                if(kind=="title") {page.title=value;if(selected==surface)title=value;}
                if(kind=="url"){if(selected==surface)address.text=value;schedule_session();}
                if(kind=="loading") {page.loading=value=="1";if(value=="0" && !is_private){string visit_url=surface.url;string visit_title=surface.page_title;app.storage.run((store) => store.visit(visit_url,visit_title));}}
                if(kind=="back" && selected==surface)back.sensitive=value=="1";
                if(kind=="forward" && selected==surface)forward.sensitive=value=="1";
                if(kind=="popup")add_tab(value);
                if(kind=="context")context_menu(surface,value);
                if(kind=="download")download_status(surface,value);
                if(kind=="fullscreen"){if(value=="1")fullscreen();else unfullscreen();}
                if(kind=="crashed") {page.indicator_icon=new ThemedIcon("dialog-warning-symbolic");EngineDialogs.show_error(this,_("This tab crashed. Reload to continue."));}
                if(kind=="error")EngineDialogs.show_error(this,value);
                if(kind=="source"){
                    try{
                        string? manifest=ManifestDiscovery.find(value,surface.url);
                        if(manifest==null)confirm_install(new WebApp(surface.page_title,surface.url));
                        else {manifest_requests[surface]=manifest;surface.engine.fetch_manifest(manifest);}
                    }catch(Error e){EngineDialogs.show_error(this,e.message);}
                }
                if(kind=="manifest" && manifest_requests.has_key(surface)){
                    string manifest_url=manifest_requests[surface];manifest_requests.unset(surface);
                    try{
                        WebApp metadata;
                        try{metadata=WebApp.from_manifest(value,manifest_url,surface.url,surface.page_title);}
                        catch(Error e){metadata=new WebApp(surface.page_title,surface.url);}
                        confirm_install(metadata);
                    }catch(Error e){EngineDialogs.show_error(this,e.message);}
                }
            });
        }
        private void bookmark () {
            if(selected==null)return; string url=selected.url,name=selected.page_title;
            app.storage.run((store) => store.bookmark(url,name));
        }
        private void site_info () {
            if(selected==null)return;
            var dialog=new Adw.AlertDialog(_("Site Information"),(selected.url.has_prefix("https://")?_("Encrypted HTTPS connection"):_("Connection is not encrypted"))+"\n"+selected.url);
            dialog.add_response("close",_("Close"));dialog.add_response("clear",_("Clear Cookies"));if(!is_private)dialog.add_response("password",_("Site Password…"));
            var view=selected.engine;string url=selected.url;dialog.response.connect((id)=>{if(id=="clear")view.clear_cookies();if(id=="password")try{new CredentialDialog(UrlResolver.origin(url),view).present(this);}catch(Error e){EngineDialogs.show_error(this,e.message);}});dialog.present(this);
        }
        private void context_menu (BrowserSurface surface,string link) {
            var menu=new Menu();
            foreach(string name in new string[]{"back","forward","reload","print","devtools"})menu.append(name,"win."+name);
            var actions=new SimpleActionGroup();
            foreach(string name in new string[]{"copy","cut","paste","select-all","source","mute"}){
                string command_name=name;var item=new SimpleAction(name,null);item.activate.connect(()=>surface.engine.command(command_name));actions.add_action(item);menu.append(name,"context."+name);
            }
            if(link!=""){
                var open=new SimpleAction("open-link",null);open.activate.connect(()=>add_tab(link));actions.add_action(open);menu.append(_("Open Link in New Tab"),"context.open-link");
                var copy=new SimpleAction("copy-link",null);copy.activate.connect(()=>get_clipboard().set_text(link));actions.add_action(copy);menu.append(_("Copy Link"),"context.copy-link");
                var window=new SimpleAction("window-link",null);window.activate.connect(()=>{var w=new BrowserWindow(app,is_private,false);w.add_tab(link);w.present();});actions.add_action(window);menu.append(_("Open Link in New Window"),"context.window-link");
            }
            surface.insert_action_group("context",actions);
            var pop=new Gtk.PopoverMenu.from_model(menu);pop.set_parent(surface);pop.closed.connect(()=>pop.unparent());pop.popup();
        }
        private void show_records (bool bookmarks) {
            var dialog=new Adw.Dialog();dialog.title=bookmarks?_("Bookmarks"):_("History");dialog.content_width=650;dialog.content_height=600;
            var layout=new Adw.ToolbarView();layout.add_top_bar(new Adw.HeaderBar());
            var box=new Gtk.Box(Gtk.Orientation.VERTICAL,6);var search=new Gtk.SearchEntry();box.append(search);
            var list=new Gtk.ListBox();list.selection_mode=Gtk.SelectionMode.NONE;
            var scroll=new Gtk.ScrolledWindow();scroll.vexpand=true;scroll.child=list;box.append(scroll);layout.content=box;dialog.child=layout;
            uint generation=0;
            ActionFunc refresh=()=>{
                uint current=++generation;string query=search.text;
                app.storage.run((store)=>{
                    var rows=store.search(bookmarks,query);
                    Idle.add(()=>{
                        if(current!=generation)return Source.REMOVE;
                        while(list.get_first_child()!=null)list.remove(list.get_first_child());
                        foreach(var record in rows){
                            var row=new Adw.ActionRow();row.use_markup=false;row.title=record.title;row.subtitle=record.url;row.activatable=true;
                            row.activated.connect(()=>{add_tab(record.url);dialog.close();});
                            var remove=new Gtk.Button.from_icon_name("user-trash-symbolic");remove.valign=Gtk.Align.CENTER;row.add_suffix(remove);
                            remove.clicked.connect(()=>{app.storage.run((s)=>s.remove(bookmarks,record.id));list.remove(row);});list.append(row);
                        }
                        return Source.REMOVE;
                    });
                });
            };
            search.search_changed.connect(()=>refresh());refresh();dialog.present(this);
        }
        private Gee.HashMap<string,string> downloads=new Gee.HashMap<string,string>();
        private Gee.HashMap<string,MajorisCef.View> download_views=new Gee.HashMap<string,MajorisCef.View>();
        private signal void downloads_changed ();
        private void download_status (BrowserSurface owner,string value) {var fields=value.split("\t");if(fields.length==4){downloads[fields[0]]=value;download_views[fields[0]]=owner.engine;downloads_changed();}}
        private void show_downloads () {
            var dialog=new Adw.Dialog();dialog.title=_("Downloads");dialog.content_width=600;
            var box=new Gtk.Box(Gtk.Orientation.VERTICAL,6);var layout=new Adw.ToolbarView();layout.add_top_bar(new Adw.HeaderBar());layout.content=box;dialog.child=layout;
            ActionFunc refresh=()=>{
                while(box.get_first_child()!=null)box.remove(box.get_first_child());
                if(downloads.size==0)box.append(new Gtk.Label(_("No downloads in this window.")));
                foreach(var value in downloads.values){
                    var f=value.split("\t");var row=new Adw.ActionRow();row.title=Path.get_basename(f[3]);row.subtitle=f[1]+"% · "+f[2];box.append(row);
                    if(f[2]=="complete"){
                        var open=new Gtk.Button.with_label(_("Open"));open.valign=Gtk.Align.CENTER;row.add_suffix(open);string path=f[3];open.clicked.connect(()=>new Gtk.FileLauncher(File.new_for_path(path)).launch.begin(this,null));
                        var folder=new Gtk.Button.from_icon_name("folder-open-symbolic");folder.valign=Gtk.Align.CENTER;row.add_suffix(folder);folder.clicked.connect(()=>new Gtk.FileLauncher(File.new_for_path(Path.get_dirname(path))).launch.begin(this,null));
                    }else if(f[2]=="active" && download_views.has_key(f[0])){
                        string id=f[0];var engine=download_views[id];
                        var pause=new Gtk.Button.from_icon_name("media-playback-pause-symbolic");pause.valign=Gtk.Align.CENTER;row.add_suffix(pause);pause.clicked.connect(()=>engine.command("download-pause:"+id));
                        var resume=new Gtk.Button.from_icon_name("media-playback-start-symbolic");resume.valign=Gtk.Align.CENTER;row.add_suffix(resume);resume.clicked.connect(()=>engine.command("download-resume:"+id));
                        var cancel=new Gtk.Button.from_icon_name("process-stop-symbolic");cancel.valign=Gtk.Align.CENTER;row.add_suffix(cancel);cancel.clicked.connect(()=>engine.command("download-cancel:"+id));
                    }
                }
            };
            ulong handler=downloads_changed.connect(()=>refresh());dialog.closed.connect(()=>disconnect(handler));refresh();
            dialog.present(this);
        }
        private void install_app () {
            if(selected!=null)selected.engine.command("source-metadata");
        }
        private void confirm_install (WebApp metadata) {
            var dialog=new Adw.AlertDialog(_("Install as App"),metadata.start_url);var name=new Gtk.Entry();name.text=metadata.name;dialog.extra_child=name;
            dialog.add_response("cancel",_("Cancel"));dialog.add_response("install",_("Install"));dialog.add_response("pin",_("Install and Pin to Dock"));
            dialog.response.connect((id)=>{
                if(id=="cancel")return;
                try {
                    metadata.name=name.text.strip();if(metadata.name=="")throw new BrowserError.INVALID_APP("Application name is empty");metadata.install_desktop(Environment.get_user_data_dir());
                    app.storage.run((store)=>store.put_app(metadata));
                    if(id=="pin" && !new DesktopShellIntegration().set_pinned(metadata.desktop_name,true))EngineDialogs.show_error(this,_("Installed. Dock pinning is unavailable on this desktop."));
                }catch(Error e){EngineDialogs.show_error(this,e.message);}
            });dialog.present(this);
        }
        private void save_session () {
            if(is_private)return;
            var b=new Json.Builder();b.begin_array();
            for(int i=0;i<tabs.n_pages;i++){var p=tabs.get_nth_page(i);var s=p.child as BrowserSurface;b.begin_object();b.set_member_name("url");b.add_string_value(s.url);b.set_member_name("pinned");b.add_boolean_value(p.pinned);b.set_member_name("active");b.add_boolean_value(p==tabs.selected_page);b.end_object();}
            b.end_array();var g=new Json.Generator();g.set_root(b.get_root());string data=g.to_data(null);
            app.storage.run((store)=>store.save_session("last",data,false));
        }
        private void schedule_session () {
            if(is_private || window_closing || session_save!=0)return;
            session_save=Timeout.add(750,()=>{session_save=0;save_session();return Source.REMOVE;});
        }
        private void restore_session () {
            app.storage.run((store)=>{
                string? data=store.session("last");
                Idle.add(()=>{
                    try {
                        if(data==null){add_tab("about:blank");return Source.REMOVE;}
                        var p=new Json.Parser();p.load_from_data(data);var array=p.get_root().get_array();Adw.TabPage? active=null;
                        foreach(var node in array.get_elements()){var o=node.get_object();add_tab(o.get_string_member("url"));tabs.set_page_pinned(tabs.selected_page,o.get_boolean_member("pinned"));if(o.get_boolean_member("active"))active=tabs.selected_page;}
                        if(active!=null)tabs.selected_page=active;if(tabs.n_pages==0)add_tab("about:blank");
                    }catch(Error e){add_tab("about:blank");}return Source.REMOVE;
                });
            });
        }
        public void smoke_test () {
            add_tab(Environment.get_variable("MAJORIS_UI_FIXTURE") ?? "about:blank");
            int stage=0;
            Timeout.add(600,()=>{
                message("GTK smoke stage %d",stage);
                if(stage!=1 && visible_dialog!=null)visible_dialog.force_close();
                switch(stage++){
                    case 0: install_app();break;
                    case 1:
                        var install=visible_dialog as Adw.AlertDialog;
                        assert(install!=null);install.response("install");break;
                    case 2: new PreferencesWindow(app).present(this);break;
                    case 3: show_records(false);break;
                    case 4: show_downloads();break;
                    case 5: if(selected!=null)new TaskManager(app,selected.engine).present();break;
                    default:
                        assert(tabs.n_pages==2);assert(selected!=null && selected.has_frame);
                        var windows=new Gee.ArrayList<Gtk.Window>();
                        foreach(var window in app.get_windows())windows.add(window);
                        foreach(var window in windows)window.close();
                        return Source.REMOVE;
                }return Source.CONTINUE;
            });
        }
    }
}
