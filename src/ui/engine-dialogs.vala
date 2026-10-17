namespace MajorisBrowser {
    public class EngineDialogs : Object {
        public static void attach (BrowserSurface surface, Gtk.Window window) {
            var settings=(window.application as Application).preferences;
            surface.changed.connect((kind,value)=>{if(kind=="ready")surface.engine.command("proxy:"+settings.get_string("proxy-address"));});
            ulong proxy=settings.changed.connect((key)=>{if(key=="proxy-address" && !surface.closed)surface.engine.command("proxy:"+settings.get_string("proxy-address"));});
            surface.notify["closed"].connect(()=>{if(surface.closed)settings.disconnect(proxy);});
            surface.changed.connect((kind,value)=>{if(kind=="operation-error" && (value.has_prefix("Picture-in-picture") || value=="save-page" || value=="save-pdf" || value=="clear-site-data" || value.contains("setting:")))show_error(surface,value);});
            surface.changed.connect((kind,value)=>{if(kind=="ready")surface.engine.command("privacy:"+(settings.get_boolean("block-third-party-cookies")?"1":"0")+":"+(settings.get_boolean("https-first")?"1":"0"));});
            ulong privacy=settings.changed.connect((key)=>{if(!surface.closed && (key=="https-first" || key=="block-third-party-cookies"))surface.engine.command("privacy:"+(settings.get_boolean("block-third-party-cookies")?"1":"0")+":"+(settings.get_boolean("https-first")?"1":"0"));});
            surface.notify["closed"].connect(()=>{if(surface.closed)settings.disconnect(privacy);});
            surface.notify["closed"].connect(()=>{if(surface.closed){var app=window.application as Application;if(app!=null)app.downloads.view_closed(surface.engine);}});
            surface.engine.request.connect ((token,kind,origin,message) => {
                Gtk.Window owner=surface.get_root() as Gtk.Window ?? window;
                if(surface.closed){surface.engine.reply(token,false,"");return;}
                if(kind=="print-setup" || kind=="print-job")return;
                if(kind.has_prefix("permission:")){permission.begin(surface,owner,token,kind.substring(11),origin);return;}
                if (kind == "file" || kind == "download") {
                    choose_file.begin (surface,owner,token,kind,message); return;
                }
                var dialog = new Adw.AlertDialog (origin,message);
                var entry = new Gtk.Entry ();
                var password=new Gtk.PasswordEntry();
                if (kind == "prompt") {dialog.extra_child = entry;try{var parser=new Json.Parser();parser.load_from_data(message);var data=parser.get_root().get_object();dialog.body=data.get_string_member("message");entry.text=data.get_string_member("default");}catch(Error e){}}
                if(kind=="http-auth"){
                    var fields=new Gtk.Box(Gtk.Orientation.VERTICAL,8);entry.placeholder_text=_("Username");fields.append(entry);fields.append(password);dialog.extra_child=fields;
                }
                dialog.add_response ("cancel",_("Cancel")); dialog.add_response ("accept",kind == "permission" ? _("Allow") : _("OK"));
                dialog.close_response = "cancel"; dialog.default_response = "cancel";
                bool completed=false;
                dialog.response.connect ((response) => {
                    if(completed)return;completed=true;string text=entry.text;
                    if(kind=="http-auth"){var b=new Json.Builder();b.begin_object();b.set_member_name("username");b.add_string_value(entry.text);b.set_member_name("password");b.add_string_value(password.text);b.end_object();var g=new Json.Generator();g.set_root(b.get_root());text=g.to_data(null);password.text="";}
                    surface.engine.reply(token,response=="accept" && !surface.closed,text);
                });
                ulong closing=surface.notify["closed"].connect(()=>{if(surface.closed)dialog.force_close();});
                ulong dismissed=surface.engine.event.connect((event,value)=>{if(event=="request-dismissed" && int.parse(value)==token){completed=true;dialog.force_close();}});
                dialog.closed.connect(()=>{surface.disconnect(closing);surface.engine.disconnect(dismissed);});
                dialog.present (owner);
            });
        }
        private static async void permission(BrowserSurface surface,Gtk.Window window,int token,string names,string origin){
            var app=window.application as Application;if(app==null){surface.engine.reply(token,false,"");return;}
            bool ephemeral=window is BrowserWindow && ((BrowserWindow)window).private_mode;
            string profile=app.webapp==null?"browser":app.webapp.id;string[] kinds=names.split(",");
            int decision=ephemeral?0:yield app.permissions.decision(profile,origin,kinds);
            if(surface.closed){surface.engine.reply(token,false,"");return;}
            if(decision!=0){surface.engine.reply(token,decision==1,"persistent");return;}
            var dialog=new Adw.AlertDialog(origin,_("This website wants to use: ")+names);
            dialog.add_response("cancel",_("Not Now"));dialog.add_response("block",_("Block"));dialog.add_response("once",_("Allow Once"));if(!ephemeral)dialog.add_response("always",_("Always Allow"));dialog.close_response="cancel";dialog.default_response="cancel";
            bool completed=false;
            dialog.response.connect((id)=>{
                if(completed)return;completed=true;bool allow=id=="once" || id=="always";
                if(!ephemeral && !surface.closed && (id=="always" || id=="block"))app.permissions.remember(profile,origin,kinds,allow?1:2);
                surface.engine.reply(token,allow && !surface.closed,id=="once"?"once":id=="always" || id=="block"?"persistent":"dismiss");
            });
            ulong closing=surface.notify["closed"].connect(()=>{if(surface.closed)dialog.force_close();});
            ulong dismissed=surface.engine.event.connect((event,value)=>{if(event=="request-dismissed" && int.parse(value)==token){completed=true;dialog.force_close();}});
            dialog.closed.connect(()=>{surface.disconnect(closing);surface.engine.disconnect(dismissed);});dialog.present(window);
        }
        private static async void choose_file (BrowserSurface surface,Gtk.Window window,int token,string kind,string message) {
            var dialog = new Gtk.FileDialog ();
            var cancellable=new Cancellable();
            ulong closing=surface.notify["closed"].connect(()=>{if(surface.closed)cancellable.cancel();});
            try {
                if(kind=="download"){
                    var app=window.application as Application;
                    string folder=app.preferences.get_string("download-directory");
                    if(folder=="")folder=Environment.get_user_special_dir(UserDirectory.DOWNLOAD) ?? Environment.get_home_dir();
                    string filename=Path.get_basename(message);if(filename=="." || filename==".." || filename=="")filename="download";
                    dialog.initial_name=filename;dialog.initial_folder=File.new_for_path(folder);
                    if(!app.preferences.get_boolean("ask-download")){
                        string target=Path.build_filename(folder,filename);int suffix=1;
                        while(FileUtils.test(target,FileTest.EXISTS))target=Path.build_filename(folder,filename+" ("+(suffix++).to_string()+")");
                        surface.engine.reply(token,!surface.closed,target);
                    }else{var selected=yield dialog.save(window,cancellable);surface.engine.reply(token,!surface.closed,selected.get_path());}
                }else{
                    var parser=new Json.Parser();parser.load_from_data(message);var options=parser.get_root().get_object();int mode=(int)options.get_int_member("mode");
                    string initial=options.get_string_member("initial");if(initial!="")dialog.initial_file=File.new_for_path(initial);
                    var filters=new ListStore(typeof(Gtk.FileFilter));
                    foreach(var node in options.get_array_member("filters").get_elements()){
                        string value=node.get_string();var filter=new Gtk.FileFilter();filter.name=value;
                        if(value.has_prefix("."))filter.add_suffix(value.substring(1));else if(value.contains("/"))filter.add_mime_type(value);else filter.add_pattern(value);filters.append(filter);
                    }if(filters.get_n_items()>0)dialog.filters=filters;
                    var paths=new Json.Builder();paths.begin_array();
                    if(mode==1){var selected=yield dialog.open_multiple(window,cancellable);for(uint i=0;i<selected.get_n_items();i++){var file=selected.get_item(i) as File;if(file!=null && file.get_path()!=null)paths.add_string_value(file.get_path());}}
                    else {File file;if(mode==2)file=yield dialog.select_folder(window,cancellable);else if(mode==3)file=yield dialog.save(window,cancellable);else file=yield dialog.open(window,cancellable);if(file.get_path()==null)throw new IOError.NOT_SUPPORTED("This file cannot be passed to the web engine");paths.add_string_value(file.get_path());}
                    paths.end_array();var generator=new Json.Generator();generator.set_root(paths.get_root());surface.engine.reply(token,!surface.closed,generator.to_data(null));
                }
            } catch (Error e) { surface.engine.reply (token,false,""); }
            surface.disconnect(closing);
        }
        public static void show_error (Gtk.Widget parent,string message) {
            var dialog = new Adw.AlertDialog (_("Browser"),message); dialog.add_response ("ok",_("OK")); dialog.present (parent);
        }
    }
}
