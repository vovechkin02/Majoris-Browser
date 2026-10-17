namespace MajorisBrowser {
    public class PreferencesWindow : Adw.PreferencesDialog {
        public PreferencesWindow (Application app) {
            title=_("Browser Settings");
            var general=new Adw.PreferencesPage();general.title=_("General");general.icon_name="preferences-system-symbolic";add(general);
            var group=new Adw.PreferencesGroup();group.title=_("Startup and Search");general.add(group);
            var homepage=new Adw.EntryRow();homepage.title=_("Homepage");app.preferences.bind("homepage",homepage,"text",SettingsBindFlags.DEFAULT);group.add(homepage);
            var restore=new Adw.SwitchRow();restore.title=_("Restore Previous Session");restore.active=app.preferences.get_string("startup")=="restore";restore.notify["active"].connect(()=>app.preferences.set_string("startup",restore.active?"restore":"new-tab"));group.add(restore);
            var search=new Adw.ComboRow();search.title=_("Search Engine");search.model=new Gtk.StringList({"DuckDuckGo","Google","Bing"});group.add(search);
            string[] templates={"https://duckduckgo.com/?q=%s","https://www.google.com/search?q=%s","https://www.bing.com/search?q=%s"};
            for(int i=0;i<templates.length;i++)if(templates[i]==app.preferences.get_string("search-template"))search.selected=i;
            search.notify["selected"].connect(()=>app.preferences.set_string("search-template",templates[search.selected]));
            var default_browser=new Adw.ActionRow();default_browser.title=_("Set as Default Browser");var set_default=new Gtk.Button.with_label(_("Set Default"));set_default.valign=Gtk.Align.CENTER;default_browser.add_suffix(set_default);group.add(default_browser);
            set_default.clicked.connect(()=>{
                try {var info=new DesktopAppInfo("com.majoris.browser.desktop");if(info!=null){info.set_as_default_for_type("x-scheme-handler/http");info.set_as_default_for_type("x-scheme-handler/https");}}
                catch(Error e){EngineDialogs.show_error(this,e.message);}
            });
            var privacy=new Adw.PreferencesPage();privacy.title=_("Privacy");privacy.icon_name="security-high-symbolic";add(privacy);
            var data=new Adw.PreferencesGroup();data.title=_("Browser Data");privacy.add(data);
            var clear=new Adw.ActionRow();clear.title=_("Clear Browsing History");var clear_button=new Gtk.Button.with_label(_("Clear"));clear_button.valign=Gtk.Align.CENTER;clear.add_suffix(clear_button);data.add(clear);
            clear_button.clicked.connect(()=>{
                var confirm=new Adw.AlertDialog(_("Clear Browser History?"),_("Installed web apps keep their independent profiles."));confirm.add_response("cancel",_("Cancel"));confirm.add_response("clear",_("Clear"));confirm.set_response_appearance("clear",Adw.ResponseAppearance.DESTRUCTIVE);confirm.response.connect((id)=>{if(id=="clear")app.storage.run((store)=>store.clear_history());});confirm.present(this);
            });
            var site_data=new Adw.ActionRow();site_data.title=_("Clear Browser Cookies and Site Data");site_data.subtitle=_("Closes Browser windows. Installed web apps keep their data.");
            var clear_sites=new Gtk.Button.with_label(_("Clear…"));clear_sites.valign=Gtk.Align.CENTER;site_data.add_suffix(clear_sites);data.add(site_data);
            clear_sites.clicked.connect(()=>{
                var confirm=new Adw.AlertDialog(_("Clear Browser Site Data?"),_("Browser will close and remove its cookies, cache and site storage. Installed web apps remain independent."));confirm.add_response("cancel",_("Cancel"));confirm.add_response("clear",_("Clear and Close Browser"));confirm.set_response_appearance("clear",Adw.ResponseAppearance.DESTRUCTIVE);confirm.response.connect((id)=>{if(id=="clear"){force_close();app.clear_browser_profile();}});confirm.present(this);
            });
            var webapps=new Adw.PreferencesPage();webapps.title=_("Web Apps");webapps.icon_name="application-x-executable-symbolic";add(webapps);
            var apps=new Adw.PreferencesGroup();apps.title=_("Installed Applications");webapps.add(apps);
            app.storage.run((store)=>{
                var installed=store.apps();
                Idle.add(()=>{
                    foreach(var metadata in installed){
                        var row=new Adw.ActionRow();row.use_markup=false;row.title=metadata.name;row.subtitle=metadata.start_url;apps.add(row);
                        var open=new Gtk.Button.from_icon_name("media-playback-start-symbolic");open.tooltip_text=_("Open");open.valign=Gtk.Align.CENTER;row.add_suffix(open);open.clicked.connect(()=>{try{new Subprocess.newv({"majoris-browser","--app="+metadata.id},SubprocessFlags.NONE);}catch(Error e){EngineDialogs.show_error(this,e.message);}});
                        var pin=new Gtk.Button.from_icon_name("view-pin-symbolic");pin.tooltip_text=_("Pin to Dock");pin.valign=Gtk.Align.CENTER;row.add_suffix(pin);pin.clicked.connect(()=>{if(!new DesktopShellIntegration().set_pinned(metadata.desktop_name,true))EngineDialogs.show_error(this,_("Dock integration is unavailable."));});
                        var clear_app=new Gtk.Button.from_icon_name("edit-clear-all-symbolic");clear_app.tooltip_text=_("Clear Application Data");clear_app.valign=Gtk.Align.CENTER;row.add_suffix(clear_app);
                        clear_app.clicked.connect(()=>{
                            var confirm=new Adw.AlertDialog(_("Clear Application Data?"),_("Close this application first. This removes its sign-in sessions and site storage, independently of Browser."));confirm.add_response("cancel",_("Cancel"));confirm.add_response("clear",_("Clear"));confirm.set_response_appearance("clear",Adw.ResponseAppearance.DESTRUCTIVE);confirm.response.connect((id)=>{
                                if(id=="clear")try{ProfileCleaner.clear.begin(app.paths.webapp_context(metadata.id),(obj,res)=>{try{ProfileCleaner.clear.end(res);}catch(Error e){EngineDialogs.show_error(this,e.message);}});}catch(Error e){EngineDialogs.show_error(this,e.message);}
                            });confirm.present(this);
                        });
                        var remove=new Gtk.Button.from_icon_name("user-trash-symbolic");remove.tooltip_text=_("Uninstall");remove.valign=Gtk.Align.CENTER;row.add_suffix(remove);
                        remove.clicked.connect(()=>{
                            var confirm=new Adw.AlertDialog(_("Uninstall Application?"),_("Its site data will be retained. Close the app before uninstalling."));confirm.add_response("cancel",_("Cancel"));confirm.add_response("remove",_("Uninstall"));confirm.set_response_appearance("remove",Adw.ResponseAppearance.DESTRUCTIVE);
                            confirm.response.connect((id)=>{if(id=="remove"){
                                try{File.new_for_path(Path.build_filename(Environment.get_user_data_dir(),"applications",metadata.desktop_name)).delete();new DesktopShellIntegration().set_pinned(metadata.desktop_name,false);app.storage.run((s)=>s.delete_app(metadata.id));apps.remove(row);}catch(Error e){EngineDialogs.show_error(this,e.message);}
                            }});confirm.present(this);
                        });
                    }return Source.REMOVE;
                });
            });
        }
    }
}
