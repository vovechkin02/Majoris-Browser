namespace MajorisBrowser {
    public class ImportDialog : Adw.AlertDialog {
        private Application app;
        public ImportDialog(Application app){
            Object(heading:_("Import Browser Data"),body:_("Close the source browser first. Select a portable bookmark HTML file, Chromium/Brave Bookmarks JSON, or a Chromium/Firefox history database. The source is read only. Password import is not supported."));this.app=app;
            add_response("cancel",_("Cancel"));add_response("html",_("Bookmark HTML"));add_response("json",_("Chromium Bookmarks"));add_response("chromium",_("Chromium History"));add_response("firefox",_("Firefox History"));response.connect((id)=>{if(id!="cancel")choose.begin(id);});
        }
        private async void choose(string kind){
            var parent=get_root() as Gtk.Window;
            try{var dialog=new Gtk.FileDialog();var file=yield dialog.open(parent,null);string? path=file.get_path();if(path==null)throw new IOError.NOT_SUPPORTED("Select a local file");app.hold();app.storage.run((store)=>{
                int count=0;string? error=null;try{
                    if(kind=="chromium" || kind=="firefox")count=ProfileImport.history(store,path,kind=="firefox");
                    else{string text;var info=file.query_info(FileAttribute.STANDARD_SIZE,FileQueryInfoFlags.NONE);if(info.get_size()>8*1024*1024)throw new IOError.INVALID_DATA("Bookmark file exceeds 8 MiB");FileUtils.get_contents(path,out text);if(kind=="json")count=ProfileImport.chromium_bookmarks(store,text);else foreach(var record in BookmarkFormat.parse(text)){store.bookmark(record.url,record.title,record.folder);count++;}}
                }catch(Error e){error=e.message;}
                Idle.add(()=>{if(parent!=null){var result=new Adw.AlertDialog(error==null?_("Import Complete"):_("Import Failed"),error??_("Imported %d records.").printf(count));result.add_response("ok",_("OK"));result.present(parent);}app.release();return Source.REMOVE;});
            });}catch(Error e){if(parent!=null)EngineDialogs.show_error(parent,e.message);}
        }
    }
    public class FirstRun : Object {
        public static void present(Application app,Gtk.Window window){
            if(app.preferences.get_boolean("setup-complete"))return;app.preferences.set_boolean("setup-complete",true);
            var dialog=new Adw.AlertDialog(_("Welcome to Majoris Browser"),_("Choose a search engine. You can import bookmarks and history now or later in Settings."));var box=new Gtk.Box(Gtk.Orientation.VERTICAL,8);var search=new Gtk.DropDown.from_strings({"DuckDuckGo","Google","Bing"});box.append(search);var defaults=new Gtk.CheckButton.with_label(_("Make Majoris Browser the default browser"));box.append(defaults);dialog.extra_child=box;dialog.add_response("skip",_("Get Started"));dialog.add_response("import",_("Import Data…"));
            dialog.response.connect((id)=>{string[] templates={"https://duckduckgo.com/?q=%s","https://www.google.com/search?q=%s","https://www.bing.com/search?q=%s"};app.preferences.set_string("search-template",templates[search.selected]);if(defaults.active)try{var info=new DesktopAppInfo("com.majoris.browser.desktop");if(info!=null){info.set_as_default_for_type("x-scheme-handler/http");info.set_as_default_for_type("x-scheme-handler/https");}}catch(Error e){EngineDialogs.show_error(window,e.message);}if(id=="import")new ImportDialog(app).present(window);});dialog.present(window);
        }
    }
}
