namespace MajorisBrowser {
    public class DownloadsDialog : Adw.Dialog {
        private Application app;
        private MajorisCef.View? engine;
        private Gtk.ListBox list=new Gtk.ListBox();
        public DownloadsDialog(Application app,MajorisCef.View? engine){
            this.app=app;this.engine=engine;title=_("Downloads");content_width=700;content_height=500;
            var layout=new Adw.ToolbarView();var header=new Adw.HeaderBar();var clear=new Gtk.Button.with_label(_("Clear Completed"));header.pack_start(clear);clear.clicked.connect(()=>app.downloads.clear_completed());layout.add_top_bar(header);var scroll=new Gtk.ScrolledWindow();scroll.child=list;layout.content=scroll;child=layout;
            ulong changed=app.downloads.changed.connect(refresh);closed.connect(()=>app.downloads.disconnect(changed));refresh();
        }
        private void refresh(){
            while(list.get_first_child()!=null)list.remove(list.get_first_child());
            foreach(var record in app.downloads.records){
                var row=new Adw.ActionRow();row.use_markup=false;row.title=record.filename==""?record.source:record.filename;
                row.subtitle="%s · %s / %s%s".printf(record.status,GLib.format_size((uint64)int64.max(0,record.received)),record.total>0?GLib.format_size((uint64)record.total):_("Unknown size"),record.speed>0?" · "+GLib.format_size((uint64)record.speed)+"/s":"");
                if(record.error_detail!="")row.subtitle+=" · "+record.error_detail;
                if(record.status=="complete"){
                    add_button(row,_("Open"),()=>launch.begin(record.destination,false));add_button(row,_("Show in Files"),()=>launch.begin(record.destination,true));
                }else if(record.control!=null && (record.status=="active" || record.status=="paused")){
                    add_button(row,record.status=="paused"?_("Resume"):_("Pause"),()=>app.downloads.command(record,record.status=="paused"?"resume":"pause"));add_button(row,_("Cancel"),()=>app.downloads.command(record,"cancel"));
                }else if(engine!=null){add_button(row,_("Retry"),()=>{try{UrlResolver.web_uri(record.source);engine.command("download:"+record.source);}catch(Error e){EngineDialogs.show_error(this,e.message);}});}
                if(record.status!="active" && record.status!="paused")add_button(row,_("Remove"),()=>app.downloads.remove(record));list.append(row);
            }
        }
        private delegate void Click();
        private void add_button(Adw.ActionRow row,string label,owned Click click){var button=new Gtk.Button.with_label(label);button.valign=Gtk.Align.CENTER;button.clicked.connect(()=>click());row.add_suffix(button);}
        private async void launch(string path,bool folder){try{var file=File.new_for_path(path);if(!file.query_exists())throw new IOError.NOT_FOUND(_("The downloaded file no longer exists."));var launcher=new Gtk.FileLauncher(file);if(folder)yield launcher.open_containing_folder(null,null);else yield launcher.launch(null,null);}catch(Error e){EngineDialogs.show_error(this,e.message);}}
    }
}
