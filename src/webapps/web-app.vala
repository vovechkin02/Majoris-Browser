namespace MajorisBrowser {
    public class WebApp : Object {
        public string id;
        public string name;
        public string start_url;
        public string scope;
        public string scope_source="explicit";
        public static string proposed_scope(string url) throws Error {
            string path=WebAppNavigationPolicy.normalized_path(url);
            if(!path.has_suffix("/")){int slash=path.index_of("/",1);path=slash>0?path.substring(0,slash+1):"/";}
            return UrlResolver.origin(url)+path;
        }
        public int64 installed_at;
        public string manifest_url="";
        public string icon_url="";
        public string icon_path="";
        public string theme_color="";
        public string background_color="";
        public string display_mode="standalone";
        public string application_id { owned get { return "com.majoris.browser.WebApp." + id; } }
        public string desktop_name { owned get { return application_id + ".desktop"; } }
        public WebApp (string name, string url, string? scope = null) throws Error {
            UrlResolver.web_uri (url);
            this.id = "a" + Uuid.string_random ().replace ("-", "");
            this.name = name.strip ();
            if (this.name == "") throw new BrowserError.INVALID_APP ("Application name is empty");
            this.start_url = url;
            this.scope = scope ?? proposed_scope(url);
            if(scope==null)scope_source="inferred";
            if (new WebAppNavigationPolicy (this.scope).classify (url) != NavigationDecision.APP_SCOPE)
                throw new BrowserError.INVALID_APP ("Start URL must be in application scope");
            installed_at = new DateTime.now_utc ().to_unix ();
        }
        public string serialize () {
            var b = new Json.Builder (); b.begin_object ();
            b.set_member_name ("id"); b.add_string_value (id);
            b.set_member_name ("name"); b.add_string_value (name);
            b.set_member_name ("start_url"); b.add_string_value (start_url);
            b.set_member_name ("scope"); b.add_string_value (scope);
            b.set_member_name("scope_source");b.add_string_value(scope_source);
            b.set_member_name ("installed_at"); b.add_int_value (installed_at);
            b.set_member_name("manifest_url");b.add_string_value(manifest_url);
            b.set_member_name("icon_url");b.add_string_value(icon_url);
            b.set_member_name("icon_path");b.add_string_value(icon_path);
            b.set_member_name("theme_color");b.add_string_value(theme_color);
            b.set_member_name("background_color");b.add_string_value(background_color);
            b.set_member_name("display_mode");b.add_string_value(display_mode);
            b.end_object (); var g = new Json.Generator (); g.set_root (b.get_root ()); return g.to_data (null);
        }
        public static WebApp deserialize (string data) throws Error {
            var p = new Json.Parser (); p.load_from_data (data);
            var o = p.get_root ().get_object ();
            foreach (string key in new string[] {"id", "name", "start_url", "scope", "installed_at"})
                if (!o.has_member (key)) throw new BrowserError.INVALID_APP ("Incomplete application metadata");
            var app = new WebApp (o.get_string_member ("name"),o.get_string_member ("start_url"),o.get_string_member ("scope"));
            app.id = o.get_string_member ("id");
            if (!ProfilePaths.valid_id (app.id)) throw new BrowserError.INVALID_APP ("Invalid application ID");
            app.installed_at = o.get_int_member ("installed_at");
            app.scope_source=o.has_member("scope_source")?o.get_string_member("scope_source"):"legacy";
            if(o.has_member("manifest_url"))app.manifest_url=o.get_string_member("manifest_url");
            if(o.has_member("icon_url"))app.icon_url=o.get_string_member("icon_url");
            if(o.has_member("icon_path"))app.icon_path=o.get_string_member("icon_path");
            if(o.has_member("theme_color"))app.theme_color=o.get_string_member("theme_color");
            if(o.has_member("background_color"))app.background_color=o.get_string_member("background_color");
            if(o.has_member("display_mode"))app.display_mode=o.get_string_member("display_mode");
            return app;
        }
        public static WebApp from_manifest(string text,string manifest_url,string document_url,string fallback_title) throws Error {
            var parser=new Json.Parser();parser.load_from_data(text);
            if(parser.get_root().get_node_type()!=Json.NodeType.OBJECT)throw new BrowserError.INVALID_APP("Manifest must be an object");
            var object=parser.get_root().get_object();
            foreach(string key in new string[]{"name","short_name","start_url","scope","display"})
                if(object.has_member(key) && object.get_member(key).get_value_type()!=typeof(string))throw new BrowserError.INVALID_APP("Invalid manifest field");
            string name=object.has_member("name")?object.get_string_member("name"):object.has_member("short_name")?object.get_string_member("short_name"):fallback_title;
            string start=object.has_member("start_url")?Uri.resolve_relative(manifest_url,object.get_string_member("start_url"),UriFlags.NONE):document_url;
            if(UrlResolver.origin(start)!=UrlResolver.origin(document_url))throw new BrowserError.INVALID_APP("Manifest start URL must belong to the installing site");
            string scope=object.has_member("scope")?Uri.resolve_relative(manifest_url,object.get_string_member("scope"),UriFlags.NONE):Uri.resolve_relative(start,".",UriFlags.NONE);
            var result=new WebApp(name,start,scope);result.manifest_url=manifest_url;result.scope_source="manifest";
            if(object.has_member("display"))result.display_mode=object.get_string_member("display");
            foreach(string field in new string[]{"theme_color","background_color"})if(object.has_member(field) && object.get_member(field).get_value_type()==typeof(string)){
                if(field=="theme_color")result.theme_color=object.get_string_member(field);else result.background_color=object.get_string_member(field);
            }
            if(object.has_member("icons") && object.get_member("icons").get_node_type()==Json.NodeType.ARRAY){
                int best=0;
                foreach(var node in object.get_array_member("icons").get_elements()){
                    if(node.get_node_type()!=Json.NodeType.OBJECT)continue;var icon=node.get_object();
                    if(!icon.has_member("src") || icon.get_member("src").get_value_type()!=typeof(string))continue;
                    try{
                        string url=Uri.resolve_relative(manifest_url,icon.get_string_member("src"),UriFlags.NONE);UrlResolver.web_uri(url);
                        int size=128;
                        if(icon.has_member("sizes") && icon.get_member("sizes").get_value_type()==typeof(string))foreach(string pair in icon.get_string_member("sizes").split(" ")){
                            string[] sides=pair.split("x");if(sides.length==2){int parsed=int.parse(sides[0]);if(parsed>0 && parsed<=1024)size=parsed;}
                        }
                        if(size>=best){best=size;result.icon_url=url;}
                    }catch(Error e){}
                }
            }
            return result;
        }
        public void install_desktop (string data_home) throws Error {
            var dir = Path.build_filename (data_home, "applications");
            DirUtils.create_with_parents (dir,0700);
            var key = new KeyFile ();
            key.set_string ("Desktop Entry", "Type", "Application");
            key.set_string ("Desktop Entry", "Name", name);
            key.set_string ("Desktop Entry", "Exec", "majoris-browser --app=" + id);
            key.set_string ("Desktop Entry", "Icon", icon_path!=""?icon_path:"com.majoris.browser");
            key.set_string ("Desktop Entry", "StartupWMClass", application_id);
            key.set_string ("Desktop Entry", "Categories", "Network;WebBrowser;");
            key.set_boolean ("Desktop Entry", "Terminal", false);
            FileUtils.set_contents (Path.build_filename (dir,desktop_name),key.to_data ());
        }
    }
}
