namespace MajorisBrowser {
    public class WebAppInstaller : Object {
        // Called on the storage worker. The launcher is the final publication step.
        public static void install (Store store,WebApp app,string data_home,Bytes? image=null) throws Error {
            if(!ProfilePaths.valid_id(app.id))throw new BrowserError.INVALID_APP("Invalid application identity");
            if(store.get_app(app.id)!=null)throw new BrowserError.INVALID_APP("Application is already installed");
            UrlResolver.web_uri(app.start_url);
            if(new WebAppNavigationPolicy(app.scope).classify(app.start_url)!=NavigationDecision.APP_SCOPE)
                throw new BrowserError.INVALID_APP("Invalid application scope");
            var paths=new ProfilePaths(data_home);
            string profile=paths.webapp_context(app.id);
            string icons=Path.build_filename(data_home,"icons","hicolor",image==null?"scalable":"256x256","apps");
            if(DirUtils.create_with_parents(icons,0700)!=0 || DirUtils.create_with_parents(profile,0700)!=0)
                throw new FileError.FAILED("Cannot allocate application storage");
            string icon=Path.build_filename(icons,app.application_id+(image==null?".svg":".png"));
            string desktop=Path.build_filename(data_home,"applications",app.desktop_name);
            if(FileUtils.test(desktop,FileTest.EXISTS) || FileUtils.test(icon,FileTest.EXISTS))throw new BrowserError.INVALID_APP("Application files already exist");
            bool registered=false;
            try {
                if(image==null){
                    string letter=Markup.escape_text(app.name.get_char().to_string().up());
                    string svg="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"128\" height=\"128\"><rect width=\"128\" height=\"128\" rx=\"16\" fill=\"#%06x\"/><text x=\"64\" y=\"88\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"76\" fill=\"white\">%s</text></svg>".printf((app.name.hash() & 0x7f7f7f)|0x303030,letter);
                    FileUtils.set_contents(icon,svg);
                }else {
                    unowned uint8[] bytes=image.get_data();
                    if(bytes.length<24 || bytes.length>2*1024*1024 || bytes[0]!=137 || bytes[1]!=80 || bytes[2]!=78 || bytes[3]!=71)
                        throw new BrowserError.INVALID_APP("Invalid icon image");
                    File.new_for_path(icon).replace_contents(bytes,null,false,FileCreateFlags.PRIVATE,null);
                }
                app.icon_path=icon;
                store.put_app(app);registered=true;
                app.install_desktop(data_home); // GLib atomic replacement, after registry commit.
            }catch(Error e){
                if(registered)store.delete_app(app.id);
                FileUtils.remove(desktop);FileUtils.remove(icon);DirUtils.remove(profile);
                throw e;
            }
        }
    }
}
