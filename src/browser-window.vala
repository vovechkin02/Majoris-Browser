namespace MajorisBrowser {
    public class BrowserWindow : Adw.ApplicationWindow {
        private Application app;
        private bool is_private;
        public bool private_mode { get { return is_private; } }
        private Adw.TabView tabs = new Adw.TabView ();
        private Gtk.Entry address = new Gtk.Entry ();
        private Omnibox omnibox;
        private Gtk.Button back;
        private Gtk.Button forward;
        private Gtk.Button reload;
        private Gtk.Button site_button;
        private Gtk.Box bookmarks_bar=new Gtk.Box(Gtk.Orientation.HORIZONTAL,6);
        private uint bookmarks_generation;
        private ulong bookmarks_handler;
        private Gee.ArrayList<TabState> closed = new Gee.ArrayList<TabState> ();
        private uint session_save=0;
        private Gee.HashMap<BrowserSurface,string> manifest_requests=new Gee.HashMap<BrowserSurface,string>();
        private Gee.HashMap<string,WebApp> icon_requests=new Gee.HashMap<string,WebApp>();
        private bool window_closing=false;
        private bool window_close_pending;
        private int tab_closes_pending;
        private bool close_downloads_confirmed;
        private Gtk.SearchEntry find = new Gtk.SearchEntry ();
        private Gtk.Revealer find_bar = new Gtk.Revealer ();
        private string window_id = Uuid.string_random ();
        private BrowserSurface? selected { get { return tabs.selected_page == null ? null : tabs.selected_page.child as BrowserSurface; } }
        public BrowserWindow (Application app,bool is_private,bool initial_tab = true) {
            Object (application:app,title:is_private ? _("Private Browser") : _("Browser"),default_width:1200,default_height:800);
            this.app=app; this.is_private=is_private;
            omnibox=new Omnibox(address,app,()=>{var result=new Gee.ArrayList<Record>();for(int i=0;i<tabs.n_pages;i++){var surface=tabs.get_nth_page(i).child as BrowserSurface;result.add(new Record(i,surface.url,surface.page_title));}return result;});
            omnibox.accepted.connect((url)=>{for(int i=0;i<tabs.n_pages;i++){var page=tabs.get_nth_page(i);if(((BrowserSurface)page.child).url==url){tabs.selected_page=page;return;}}if(selected!=null)selected.navigate(url);});
            var layout = new Adw.ToolbarView ();
            var header = new Adw.HeaderBar (); header.decoration_layout=":minimize,maximize,close";
            header.title_widget = new Gtk.Label (is_private ? _("Private Browsing") : _("Browser"));
            var plus = new Gtk.Button.from_icon_name ("list-add-symbolic"); plus.tooltip_text=_("New Tab"); plus.clicked.connect (() => add_tab ("about:blank")); header.pack_start (plus);
            var menu = new Menu ();
            string[,] entries = {{"New Tab","new-tab"},{"New Window","new-window"},{"Private Window","private"},{"Duplicate Tab","duplicate"},{"Pin / Unpin Tab","pin"},{"Reopen Closed Tab","reopen"},{"Bookmarks","bookmarks"},{"History","history"},{"Downloads","downloads"},{"Find in Page","find"},{"Install as App…","install-app"},{"Settings","settings"},{"Task Manager","tasks"},{"Developer Tools","devtools"},{"About Browser","about"}};
            for (int i=0;i<entries.length[0];i++) menu.append (_(entries[i,0]),"win."+entries[i,1]);
            menu.append(_("Save Page…"),"win.save-page");menu.append(_("Save as PDF…"),"win.save-pdf");menu.append(_("Fill Address…"),"win.fill-address");menu.append(_("Quit Browser"),"win.quit");
            menu.append(_("Picture in Picture"),"win.picture-in-picture");
            var menu_button = new Gtk.MenuButton (); menu_button.icon_name="open-menu-symbolic"; menu_button.menu_model=menu; header.pack_end (menu_button); layout.add_top_bar (header);
            var bar = new Adw.TabBar (); bar.view=tabs; layout.add_top_bar (bar);
            var tab_menu=new Menu();foreach(string name in new string[]{"duplicate","pin","move-window","close-others","close-right","close-tab"})tab_menu.append(name,"win."+name);tabs.menu_model=tab_menu;
            tabs.setup_menu.connect((page)=>{if(page!=null)tabs.selected_page=page;});
            tabs.indicator_activated.connect((page)=>((BrowserSurface)page.child).engine.command("mute"));
            var nav = new Gtk.Box (Gtk.Orientation.HORIZONTAL,6); nav.margin_start=8;nav.margin_end=8;nav.margin_top=6;nav.margin_bottom=6;
            back=button ("go-previous-symbolic",_("Back"),() => command ("back")); nav.append (back);
            forward=button ("go-next-symbolic",_("Forward"),() => command ("forward")); nav.append (forward);
            reload=button ("view-refresh-symbolic",_("Reload"),() => command (selected!=null && selected.loading ? "stop" : "reload")); nav.append (reload);
            nav.append(button("go-home-symbolic",_("Home"),()=>{if(selected!=null)selected.navigate(UrlResolver.resolve(app.preferences.get_string("homepage")));}));
            site_button=button("security-medium-symbolic",_("Site Information"),site_info);nav.append(site_button);
            address.hexpand=true; address.placeholder_text=_("Search or enter address"); address.activate.connect (() => { if(selected!=null) selected.navigate (UrlResolver.resolve (address.text,app.preferences.get_string ("search-template"))); }); nav.append (address);
            nav.append (button ("star-new-symbolic",_("Bookmark Page"),bookmark)); layout.add_top_bar (nav);
            var bookmark_scroll=new Gtk.ScrolledWindow();bookmark_scroll.set_policy(Gtk.PolicyType.AUTOMATIC,Gtk.PolicyType.NEVER);bookmark_scroll.child=bookmarks_bar;layout.add_top_bar(bookmark_scroll);app.preferences.bind("show-bookmarks-bar",bookmark_scroll,"visible",SettingsBindFlags.GET);refresh_bookmarks();
            bookmarks_handler=app.bookmarks_changed.connect(refresh_bookmarks);
            var body = new Gtk.Box (Gtk.Orientation.VERTICAL,0);
            find_bar.child=find; find.search_changed.connect (() => command ("find:"+find.text)); body.append (find_bar); body.append (tabs); tabs.vexpand=true;
            layout.content=body; content=layout;
            tabs.notify["selected-page"].connect (() => { sync_navigation();app.sessions.changed(); });
            tabs.page_reordered.connect(()=>app.sessions.changed());
            tabs.page_attached.connect(()=>app.sessions.changed());
            tabs.page_detached.connect(()=>app.sessions.changed());
            tabs.close_page.connect ((page) => {
                if(window_close_pending){tabs.close_page_finish(page,false);return true;}
                close_tab.begin(page);return true;
            });
            setup_actions ();
            close_request.connect (() => {
                if(window_closing)return false;
                if(window_close_pending || tab_closes_pending>0)return true;
                if(!close_downloads_confirmed){for(int i=0;i<tabs.n_pages;i++)if(app.downloads.active_for(((BrowserSurface)tabs.get_nth_page(i).child).engine)){
                    var dialog=new Adw.AlertDialog(_("Cancel Downloads and Close?"),_("This window still has active downloads."));dialog.add_response("cancel",_("Keep Open"));dialog.add_response("close",_("Cancel Downloads and Close"));dialog.close_response="cancel";dialog.response.connect((id)=>{if(id=="close"){close_downloads_confirmed=true;close();}else app.sessions.closing_all=false;});dialog.present(this);return true;
                }}
                close_window.begin();return true;
            });
            if(initial_tab) {
                string mode=app.preferences.get_string("startup");
                if(mode=="pages"){foreach(string url in app.preferences.get_strv("startup-pages"))add_tab(UrlResolver.resolve(url));if(tabs.n_pages==0)add_tab("about:blank");}
                else add_tab(mode=="home"?UrlResolver.resolve(app.preferences.get_string("homepage")):"about:blank");
            }
            if(!is_private && Environment.get_variable("MAJORIS_UI_SMOKE")!="1")Idle.add(()=>{if(!window_closing)FirstRun.present(app,this);return Source.REMOVE;});
        }
        private Gtk.Button button (string icon,string tooltip,owned ActionFunc callback) {
            var b=new Gtk.Button.from_icon_name(icon); b.tooltip_text=tooltip;b.clicked.connect (() => callback ());return b;
        }
        private delegate void ActionFunc ();
        private async void close_tab(Adw.TabPage page){
            tab_closes_pending++;
            var surface=(BrowserSurface)page.child;
            bool accepted=yield surface.request_close();
            if(accepted){closed.add(new TabState(surface.url,page.pinned));if(closed.size>25)closed.remove_at(0);}
            tabs.close_page_finish(page,accepted);tab_closes_pending--;
            if(accepted){schedule_session();if(tabs.n_pages==0)close();}
        }
        private async void close_window(){
            window_close_pending=true;
            var active_page=tabs.selected_page;
            for(int i=0;i<tabs.n_pages;i++){
                var surface=(BrowserSurface)tabs.get_nth_page(i).child;
                tabs.selected_page=tabs.get_nth_page(i);
                if(!(yield surface.request_close())){
                    window_close_pending=false;close_downloads_confirmed=false;app.sessions.closing_all=false;
                    // Earlier tabs may already have consented. Remove their closed engines.
                    for(int j=tabs.n_pages-1;j>=0;j--){var page=tabs.get_nth_page(j);if(((BrowserSurface)page.child).closed)tabs.close_page(page);}
                    return;
                }
            }
            if(active_page!=null)tabs.selected_page=active_page;
            app.disconnect(bookmarks_handler);omnibox.close();
            if(!is_private && !app.sessions.restoring)app.sessions.save(false,this);
            window_closing=true;
            if(session_save!=0){Source.remove(session_save);session_save=0;}
            close();
        }
        private void action (string name,string[] shortcuts,owned ActionFunc callback) {
            var a=new SimpleAction(name,null);a.activate.connect (() => callback ());add_action(a);
            if(shortcuts.length>0)app.set_accels_for_action("win."+name,shortcuts);
        }
        private void setup_actions () {
            action("new-tab",{"<Control>t"},() => add_tab("about:blank"));
            action("quit",{},()=>app.activate_action("quit",null));
            action("copy-url",{},()=>{if(selected!=null)get_clipboard().set_text(selected.url);});
            action("clear-address",{},()=>{address.text="";address.grab_focus();});
            action("paste-go",{},()=>paste_address.begin(false));
            action("paste-search",{},()=>paste_address.begin(true));
            action("new-window",{},() => new BrowserWindow(app,false).present());
            action("private",{},() => new BrowserWindow(app,true).present());
            action("focus-address",{"<Control>l"},() => {address.grab_focus();address.select_region(0,-1);});
            action("close-tab",{"<Control>w"},() => {if(tabs.selected_page!=null)tabs.close_page(tabs.selected_page);});
            action("reopen",{"<Control><Shift>t"},() => {if(closed.size>0){var state=closed.remove_at(closed.size-1);add_tab(state.url);tabs.set_page_pinned(tabs.selected_page,state.pinned);}});
            action("duplicate",{},() => {if(selected!=null)add_tab(selected.url);});
            action("tab-search",{"<Control><Shift>a"},tab_search);
            action("move-window",{},()=>{if(tabs.selected_page==null)return;var window=new BrowserWindow(app,is_private,false);tabs.transfer_page(tabs.selected_page,window.tabs,0);window.present();if(tabs.n_pages==0)close();});
            action("close-others",{},()=>{if(tabs.selected_page!=null)tabs.close_other_pages(tabs.selected_page);});
            action("close-right",{},()=>{if(tabs.selected_page!=null)tabs.close_pages_after(tabs.selected_page);});
            action("pin",{},() => {if(tabs.selected_page!=null)tabs.set_page_pinned(tabs.selected_page,!tabs.selected_page.pinned);});
            action("next-tab",{"<Control>Tab"},() => tabs.select_next_page());
            action("previous-tab",{"<Control><Shift>Tab"},() => tabs.select_previous_page());
            action("find",{"<Control>f"},() => {find_bar.reveal_child=!find_bar.reveal_child;if(find_bar.reveal_child)find.grab_focus();else command("find-stop");});
            action("bookmark",{"<Control>d"},bookmark);
            action("bookmarks",{},() => {var manager=new BookmarksDialog(app);manager.open_url.connect((url,window)=>{if(window){var next=new BrowserWindow(app,is_private,false);next.add_tab(url);next.present();}else add_tab(url);});manager.closed.connect(refresh_bookmarks);manager.present(this);});
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
            action("save-page",{"<Control>s"},()=>command("save-page"));
            action("save-pdf",{},()=>command("save-pdf"));
            action("picture-in-picture",{},()=>command("picture-in-picture"));
            action("fill-address",{},()=>{if(selected!=null)new AddressDialog(app,selected).present(this);});
            action("about",{},() => {
                var about=new Adw.AboutDialog();about.application_name="Majoris Browser";about.application_icon="com.majoris.browser";about.version=Config.VERSION;about.developer_name="Majoris";about.comments="CEF "+MajorisCef.version();about.license_type=Gtk.License.GPL_3_0;about.present(this);
            });
        }
        private void command (string name) { if(selected!=null)selected.engine.command(name); }
        private async void paste_address(bool search){try{string? value=yield get_clipboard().read_text_async(null);if(value!=null && selected!=null)selected.navigate(search?app.preferences.get_string("search-template").replace("%s",Uri.escape_string(value,null,false)):UrlResolver.resolve(value,app.preferences.get_string("search-template")));}catch(Error e){}}
        public void add_tab (string url,bool background=false) {
            add_surface(new OffscreenBrowserSurface(is_private?window_id:app.paths.browser_context,is_private,url,"",is_private?"[]":app.permissions.serialized()),background);
        }
        private void add_surface(BrowserSurface surface,bool background=false){
            app.permissions.attach(surface.engine,is_private);
            var page=tabs.append(surface);page.title=_("New Tab");if(!background)tabs.selected_page=page;
            page.notify["pinned"].connect(()=>app.sessions.changed());
            EngineDialogs.attach(surface,this);
            PageActions.attach(surface);
            if(!is_private)new CredentialController(app,surface,"browser");
            surface.changed.connect((kind,value)=>{var owner=surface.get_root() as BrowserWindow;if(owner!=null)owner.surface_event(page,surface,kind,value);});
            surface.engine.popup.connect((child,background,url,new_window)=>{var owner=surface.get_root() as BrowserWindow;if(owner==null || owner.window_closing){child.close();return;}if(new_window){var window=new BrowserWindow(app,is_private,false);window.add_surface(new OffscreenBrowserSurface.with_engine(child));window.present();}else owner.add_surface(new OffscreenBrowserSurface.with_engine(child),background);});
        }
        private void surface_event(Adw.TabPage page,BrowserSurface surface,string kind,string value){
                if(window_closing)return;
                if(kind=="closed" && !window_close_pending && tab_closes_pending==0){tabs.close_page(page);return;}
                if(kind=="title") {page.title=value;if(selected==surface)title=value;}
                if(kind=="ready")surface.engine.command("zoom:"+app.preferences.get_double("default-zoom").to_string());
                if(kind=="image:favicon" && value!="")page.icon=new BytesIcon(new Bytes(Base64.decode(value)));
                if(kind=="audio" || kind=="muted"){page.indicator_activatable=true;page.indicator_icon=new ThemedIcon(kind=="muted" && value=="1"?"audio-volume-muted-symbolic":value=="1"?"audio-volume-high-symbolic":"audio-volume-low-symbolic");}
                if(kind=="url"){if(selected==surface)omnibox.set_address(value);schedule_session();}
                if(kind=="loading") {page.loading=value=="1";if(selected==surface)sync_navigation();if(value=="0" && !is_private){string visit_url=surface.url;string visit_title=surface.page_title;app.storage.run((store) => store.visit(visit_url,visit_title));}}
                if(kind=="back" && selected==surface)back.sensitive=value=="1";
                if(kind=="security" && selected==surface){site_button.icon_name=value.has_prefix("Encrypted TLS connection")?"channel-secure-symbolic":"security-medium-symbolic";site_button.tooltip_text=value;}
                if(kind=="forward" && selected==surface)forward.sensitive=value=="1";
                if(kind=="popup")add_tab(value);
                if(kind=="popup-background")add_tab(value,true);
                if(kind=="popup-window"){var window=new BrowserWindow(app,is_private,false);window.add_tab(value);window.present();}
                if(kind=="context")context_menu(surface,value);
                if(kind=="download")app.downloads.update(surface.engine,value,is_private);
                if(kind=="fullscreen"){if(value=="1")fullscreen();else unfullscreen();}
                if(kind=="crashed")page.indicator_icon=new ThemedIcon("dialog-warning-symbolic");
                if(kind.has_prefix("image:") && icon_requests.has_key(kind.substring(6))){var metadata=icon_requests[kind.substring(6)];icon_requests.unset(metadata.id);confirm_install(metadata,value==""?surface.favicon:new Bytes(Base64.decode(value)));}
                if(kind=="source"){
                    try{
                        string? manifest=ManifestDiscovery.find(value,surface.url);
                        if(manifest==null)confirm_install(new WebApp(surface.page_title,surface.url),surface.favicon);
                        else {manifest_requests[surface]=manifest;surface.engine.fetch_manifest(manifest);}
                    }catch(Error e){EngineDialogs.show_error(this,e.message);}
                }
                if(kind=="manifest" && manifest_requests.has_key(surface)){
                    string manifest_url=manifest_requests[surface];manifest_requests.unset(surface);
                    try{
                        WebApp metadata;
                        try{metadata=WebApp.from_manifest(value,manifest_url,surface.url,surface.page_title);}
                        catch(Error e){metadata=new WebApp(surface.page_title,surface.url);}
                        if(metadata.icon_url!=""){icon_requests[metadata.id]=metadata;surface.engine.fetch_image(metadata.icon_url,metadata.id);}else confirm_install(metadata,surface.favicon);
                    }catch(Error e){EngineDialogs.show_error(this,e.message);}
                }
        }
        private void bookmark () {
            if(selected==null)return; string url=selected.url,name=selected.page_title;
            app.storage.run((store) => {store.bookmark(url,name);Idle.add(()=>{app.bookmarks_changed();return Source.REMOVE;});});
        }
        private void refresh_bookmarks(){
            uint generation=++bookmarks_generation;
            app.storage.run((store)=>{var rows=store.search(true,"",-1);var items=store.bar_items();Idle.add(()=>{
                if(window_closing || generation!=bookmarks_generation)return Source.REMOVE;
                while(bookmarks_bar.get_first_child()!=null)bookmarks_bar.remove(bookmarks_bar.get_first_child());
                foreach(var record in items){Gtk.Widget widget;
                    if(record.id!=0){var item=new Gtk.Button.with_label(record.title);item.tooltip_text=record.url;item.clicked.connect(()=>{if(selected!=null)selected.navigate(record.url);});widget=item;}
                    else{var item=new Gtk.MenuButton();item.label=record.title;var box=new Gtk.Box(Gtk.Orientation.VERTICAL,3);foreach(var bookmark in rows)if(bookmark.folder==record.title){var link=new Gtk.Button.with_label(bookmark.title);link.tooltip_text=bookmark.url;link.clicked.connect(()=>{if(selected!=null)selected.navigate(bookmark.url);item.popdown();});box.append(link);}if(box.get_first_child()==null)box.append(new Gtk.Label(_("Empty Folder")));var pop=new Gtk.Popover();pop.child=box;item.popover=pop;widget=item;}
                    bookmark_controls(widget,record);bookmarks_bar.append(widget);
                }
                return Source.REMOVE;
            });});
        }
        private void bookmark_controls(Gtk.Widget widget,Record record){
            var drag=new Gtk.DragSource();drag.actions=Gdk.DragAction.MOVE;drag.prepare.connect((x,y)=>{Value value=Value(typeof(string));value.set_string(record.folder);return new Gdk.ContentProvider.for_value(value);});widget.add_controller(drag);
            var drop=new Gtk.DropTarget(typeof(string),Gdk.DragAction.MOVE);drop.on_drop.connect((value,x,y)=>{string? key=value.get_string();if(key==null)return false;string source=key;app.storage.run((store)=>{store.reorder_bar(source,record.folder);Idle.add(()=>{app.bookmarks_changed();return Source.REMOVE;});});return true;});widget.add_controller(drop);
            var menu=new Menu();var actions=new SimpleActionGroup();
            var edit=new SimpleAction("edit",null);edit.activate.connect(()=>{
                if(record.id!=0){var manager=new BookmarksDialog(app);manager.present(this);manager.edit_bookmark(new Record(record.id,record.url,record.title));}
                else{var dialog=new Adw.AlertDialog(_("Rename Folder"),null);var name=new Gtk.Entry();name.text=record.title;dialog.extra_child=name;dialog.add_response("cancel",_("Cancel"));dialog.add_response("save",_("Save"));dialog.response.connect((id)=>{if(id!="save")return;string to=name.text;app.storage.run((store)=>{store.rename_folder(record.title,to);Idle.add(()=>{app.bookmarks_changed();return Source.REMOVE;});});});dialog.present(this);}
            });actions.add_action(edit);menu.append(_("Edit"),"bookmark.edit");
            var remove=new SimpleAction("remove",null);remove.activate.connect(()=>{app.storage.run((store)=>{if(record.id==0)store.delete_folder(record.title);else store.remove(true,record.id);Idle.add(()=>{app.bookmarks_changed();return Source.REMOVE;});});});actions.add_action(remove);menu.append(record.id==0?_("Remove Folder (Keep Bookmarks)"):_("Remove Bookmark"),"bookmark.remove");
            if(record.id!=0){var open=new SimpleAction("open",null);open.activate.connect(()=>add_tab(record.url));actions.add_action(open);menu.append(_("Open in New Tab"),"bookmark.open");var copy=new SimpleAction("copy",null);copy.activate.connect(()=>get_clipboard().set_text(record.url));actions.add_action(copy);menu.append(_("Copy Link"),"bookmark.copy");}
            widget.insert_action_group("bookmark",actions);var click=new Gtk.GestureClick();click.button=3;click.pressed.connect((n,x,y)=>{var pop=new Gtk.PopoverMenu.from_model(menu);pop.set_parent(widget);Gdk.Rectangle rect={(int)x,(int)y,1,1};pop.pointing_to=rect;pop.closed.connect(()=>pop.unparent());pop.popup();});widget.add_controller(click);
        }
        private void site_info () {
            if(selected==null)return;
            var dialog=new Adw.AlertDialog(_("Site Information"),selected.security+"\n"+selected.url);
            dialog.add_response("close",_("Close"));dialog.add_response("clear",_("Clear This Site’s Cookies"));dialog.add_response("site-data",_("Clear This Site’s Data"));if(!is_private)dialog.add_response("password",_("Site Password…"));
            var controls=new Gtk.Box(Gtk.Orientation.VERTICAL,4);
            var surface=selected;string url=surface.url;
            foreach(string kind in new string[]{"camera","microphone","location","notifications","clipboard","multiple downloads","pointer lock","keyboard lock","storage access","local fonts"}){
                var row=new Adw.ComboRow();row.title=kind;row.model=new Gtk.StringList({_("Ask"),_("Allow"),_("Block")});row.sensitive=!is_private;controls.append(row);
                if(!is_private)app.storage.run((store)=>{int value=store.permission_value("browser",url,kind);Idle.add(()=>{row.selected=value;row.notify["selected"].connect(()=>app.permissions.remember("browser",url,{kind},(int)row.selected));return Source.REMOVE;});});
            }var scroll=new Gtk.ScrolledWindow();scroll.min_content_height=250;scroll.child=controls;dialog.extra_child=scroll;
            var view=surface.engine;dialog.response.connect((id)=>{if(id=="clear")view.clear_site_cookies(url);if(id=="site-data")view.clear_site_data(url);if(id=="password")try{new CredentialDialog(UrlResolver.origin(url),view).present(this);}catch(Error e){EngineDialogs.show_error(this,e.message);}});dialog.present(this);
        }
        private void context_menu (BrowserSurface surface,string description) {
            Json.Object data;
            try{var parser=new Json.Parser();parser.load_from_data(description);data=parser.get_root().get_object();}catch(Error e){return;}
            string link=data.get_string_member("link"),source=data.get_string_member("source"),selection=data.get_string_member("selection");
            var menu=new Menu();
            foreach(string name in new string[]{"back","forward","reload","print","devtools"})menu.append(name,"win."+name);
            var actions=new SimpleActionGroup();
            foreach(string name in new string[]{"copy","cut","paste","select-all","source","mute"}){
                if((name=="cut" || name=="paste") && !data.get_boolean_member("editable"))continue;
                if(name=="copy" && selection=="")continue;
                if(name=="mute" && data.get_int_member("media")==0)continue;
                string command_name=name;var item=new SimpleAction(name,null);item.activate.connect(()=>surface.engine.command(command_name));actions.add_action(item);menu.append(name,"context."+name);
            }
            if(source!=""){
                var save=new SimpleAction("save-media",null);save.activate.connect(()=>surface.engine.command("download:"+source));actions.add_action(save);menu.append(_("Save Media As…"),"context.save-media");
                var copy=new SimpleAction("copy-media",null);copy.activate.connect(()=>get_clipboard().set_text(source));actions.add_action(copy);menu.append(_("Copy Media Address"),"context.copy-media");
            }
            if(link!=""){
                var open=new SimpleAction("open-link",null);open.activate.connect(()=>add_tab(link));actions.add_action(open);menu.append(_("Open Link in New Tab"),"context.open-link");
                var copy=new SimpleAction("copy-link",null);copy.activate.connect(()=>get_clipboard().set_text(link));actions.add_action(copy);menu.append(_("Copy Link"),"context.copy-link");
                var window=new SimpleAction("window-link",null);window.activate.connect(()=>{var w=new BrowserWindow(app,is_private,false);w.add_tab(link);w.present();});actions.add_action(window);menu.append(_("Open Link in New Window"),"context.window-link");
            }
            surface.insert_action_group("context",actions);
            var pop=new Gtk.PopoverMenu.from_model(menu);pop.set_parent(surface);Gdk.Rectangle point={ (int)data.get_int_member("x"),(int)data.get_int_member("y"),1,1 };pop.pointing_to=point;pop.closed.connect(()=>pop.unparent());pop.popup();
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
        private void show_downloads () { new DownloadsDialog(app,selected==null?null:selected.engine).present(this); }
        private void install_app () {
            if(selected!=null)selected.engine.command("source-metadata");
        }
        private void confirm_install (WebApp metadata,Bytes? image=null) {
            var dialog=new Adw.AlertDialog(_("Install as App"),metadata.start_url);var name=new Gtk.Entry();name.text=metadata.name;dialog.extra_child=name;
            dialog.add_response("cancel",_("Cancel"));dialog.add_response("install",_("Install"));dialog.add_response("pin",_("Install and Pin to Dock"));
            dialog.response.connect((id)=>{
                if(id=="cancel")return;
                try {
                    metadata.name=name.text.strip();if(metadata.name=="")throw new BrowserError.INVALID_APP("Application name is empty");
                    bool pin=id=="pin";
                    app.hold();
                    app.storage.run((store)=>{
                        string? failure=null;
                        try{WebAppInstaller.install(store,metadata,Environment.get_user_data_dir(),image);}catch(Error e){failure=e.message;}
                        Idle.add(()=>{
                            if(!window_closing){if(failure!=null)EngineDialogs.show_error(this,failure);else if(pin && !new DesktopShellIntegration().set_pinned(metadata.desktop_name,true))EngineDialogs.show_error(this,_("Installed. Dock pinning is unavailable on this desktop."));}
                            app.release();return Source.REMOVE;
                        });
                    });
                }catch(Error e){EngineDialogs.show_error(this,e.message);}
            });dialog.present(this);
        }
        private void tab_search(){
            var dialog=new Adw.Dialog();dialog.title=_("Search Tabs");dialog.content_width=500;dialog.content_height=450;
            var layout=new Adw.ToolbarView();layout.add_top_bar(new Adw.HeaderBar());var box=new Gtk.Box(Gtk.Orientation.VERTICAL,6);var search=new Gtk.SearchEntry();var list=new Gtk.ListBox();box.append(search);var scroll=new Gtk.ScrolledWindow();scroll.vexpand=true;scroll.child=list;box.append(scroll);layout.content=box;dialog.child=layout;
            ActionFunc refresh=()=>{while(list.get_first_child()!=null)list.remove(list.get_first_child());for(int i=0;i<tabs.n_pages;i++){var page=tabs.get_nth_page(i);var surface=page.child as BrowserSurface;if(!(surface.url+surface.page_title).down().contains(search.text.down()))continue;var row=new Adw.ActionRow();row.use_markup=false;row.title=page.title;row.subtitle=surface.url;row.activatable=true;row.activated.connect(()=>{tabs.selected_page=page;dialog.close();});list.append(row);}};
            search.search_changed.connect(()=>refresh());refresh();dialog.present(this);
        }
        private void schedule_session () { if(!is_private && !window_closing)app.sessions.changed(); }
        public Json.Node export_state () {
            var b=new Json.Builder();b.begin_object();
            b.set_member_name("id");b.add_string_value(window_id);
            b.set_member_name("width");b.add_int_value(get_width()>0?get_width():default_width);b.set_member_name("height");b.add_int_value(get_height()>0?get_height():default_height);
            b.set_member_name("active-window");b.add_boolean_value(app.active_window==this);
            b.set_member_name("maximized");b.add_boolean_value(maximized);
            b.set_member_name("tabs");b.begin_array();
            for(int i=0;i<tabs.n_pages;i++){var page=tabs.get_nth_page(i);var surface=page.child as BrowserSurface;
                b.begin_object();b.set_member_name("url");b.add_string_value(surface.url);b.set_member_name("pinned");b.add_boolean_value(page.pinned);b.set_member_name("active");b.add_boolean_value(page==tabs.selected_page);b.end_object();}
            b.end_array();b.end_object();return b.get_root();
        }
        public void import_state(Json.Object state){
            if(state.has_member("id"))window_id=state.get_string_member("id");
            if(state.has_member("width"))default_width=int.max(400,(int)state.get_int_member("width"));
            if(state.has_member("height"))default_height=int.max(300,(int)state.get_int_member("height"));
            if(state.has_member("maximized") && state.get_boolean_member("maximized"))maximize();
            Adw.TabPage? active=null;
            foreach(var node in state.get_array_member("tabs").get_elements()){
                var item=node.get_object();add_tab(UrlResolver.resolve(item.get_string_member("url")));tabs.set_page_pinned(tabs.selected_page,item.get_boolean_member("pinned"));if(item.get_boolean_member("active"))active=tabs.selected_page;
            }
            if(active!=null)tabs.selected_page=active;if(tabs.n_pages==0)add_tab("about:blank");
        }
        private void sync_navigation(){
            if(selected==null)return;omnibox.set_address(selected.url);title=selected.page_title;back.sensitive=selected.can_go_back;forward.sensitive=selected.can_go_forward;
            reload.icon_name=selected.loading?"process-stop-symbolic":"view-refresh-symbolic";reload.tooltip_text=selected.loading?_("Stop"):_("Reload");
        }
        public void smoke_test () {
            add_tab(Environment.get_variable("MAJORIS_UI_FIXTURE") ?? "about:blank");
            int stage=0;
            Timeout.add(600,()=>{
                message("GTK smoke stage %d",stage);
                if(stage!=1 && visible_dialog!=null)visible_dialog.force_close();
                switch(stage++){
                    case 0: if(selected==null || selected.loading || !selected.has_frame){stage--;return Source.CONTINUE;}install_app();break;
                    case 1:
                        var install=visible_dialog as Adw.AlertDialog;
                        if(install==null){stage--;return Source.CONTINUE;}install.response("install");break;
                    case 2: new PreferencesWindow(app).present(this);break;
                    case 3: show_records(false);break;
                    case 4: show_downloads();break;
                    case 5: if(selected!=null)new TaskManager(app,selected.engine).present();break;
                    case 6:
                        string fixture=Environment.get_variable("MAJORIS_UI_FIXTURE") ?? "about:blank";
                        var second=new BrowserWindow(app,false,false);second.add_tab(fixture+"?second-window");second.present();
                        var private_window=new BrowserWindow(app,true,false);private_window.add_tab(fixture+"?private-window");private_window.present();break;
                    default:
                        assert(tabs.n_pages==2);assert(selected!=null && selected.has_frame);
                        app.activate_action("quit",null);
                        return Source.REMOVE;
                }return Source.CONTINUE;
            });
        }
    }
}
