namespace MajorisBrowser {
    public class DownloadsDialog : Adw.Dialog {
        private Application app;
        private MajorisCef.View? engine;
        private string session;
        private Gtk.ListBox list=new Gtk.ListBox();
        private Adw.ActionRow scanner_status=new Adw.ActionRow();
        public DownloadsDialog(Application app,MajorisCef.View? engine,string session=""){
            this.app=app;this.engine=engine;this.session=session;title=_("Downloads");content_width=700;content_height=500;
            var layout=new Adw.ToolbarView();var header=new Adw.HeaderBar();var clear=new Gtk.Button.with_label(_("Clear Completed"));header.pack_start(clear);clear.clicked.connect(()=>app.downloads.clear_completed(session));layout.add_top_bar(header);var scroll=new Gtk.ScrolledWindow();scroll.child=list;scroll.vexpand=true;var content=new Gtk.Box(Gtk.Orientation.VERTICAL,0);scanner_status.use_markup=false;scanner_status.title=_("Download Scanner");add_button(scanner_status,_("Check Scanner"),()=>app.downloads.refresh_scanner.begin());content.append(scanner_status);content.append(scroll);layout.content=content;child=layout;
            ulong changed=app.downloads.changed.connect(refresh);uint health_timer=Timeout.add_seconds(15,()=>{app.downloads.refresh_scanner.begin();return Source.CONTINUE;});closed.connect(()=>{Source.remove(health_timer);app.downloads.disconnect(changed);});app.downloads.refresh_scanner.begin();refresh();
        }
        private void refresh(){
            scanner_status.subtitle=app.downloads.scanner_label+" · "+app.downloads.scanner_detail;
            while(list.get_first_child()!=null)list.remove(list.get_first_child());
            foreach(var record in app.downloads.records){
                if(!app.downloads.owns(record,session))continue;
                var row=new Adw.ActionRow();row.use_markup=false;row.title=record.filename==""?record.source:record.filename;
                row.subtitle="%s · %s / %s%s".printf(record.status,GLib.format_size((uint64)int64.max(0,record.received)),record.total>0?GLib.format_size((uint64)record.total):_("Unknown size"),record.speed>0?" · "+GLib.format_size((uint64)record.speed)+"/s":"");
                if(record.error_detail!="")row.subtitle+=" · "+record.error_detail;
                row.subtitle+=" · "+_(record.assessment_label);
                if(record.assessment_detail!="")row.subtitle+=" · "+record.assessment_detail;
                if(record.status=="complete"){
                    if(record.assessment==DownloadAssessment.PENDING)add_button(row,_("Cancel Scan"),()=>app.downloads.cancel_scan(record,session));
                    else if(app.downloads.scanner_available && record.assessment!=DownloadAssessment.MALICIOUS && record.assessment!=DownloadAssessment.POLICY_BLOCKED)add_button(row,_("Scan"),()=>app.downloads.scan.begin(record,session));
                    add_button(row,_("Open"),()=>open_record.begin(record)).sensitive=record.may_open;add_button(row,_("Show in Files"),()=>{if(app.downloads.owns(record,session))launch.begin(record.destination,true);});
                }else if(record.control!=null && (record.status=="active" || record.status=="paused")){
                    add_button(row,record.status=="paused"?_("Resume"):_("Pause"),()=>app.downloads.command(record,record.status=="paused"?"resume":"pause",session));add_button(row,_("Cancel"),()=>app.downloads.command(record,"cancel",session));
                }else if(engine!=null){add_button(row,_("Retry"),()=>app.downloads.retry(record,engine,session));}
                if(record.status!="active" && record.status!="paused")add_button(row,_("Remove"),()=>app.downloads.remove(record,session));list.append(row);
            }
        }
        private delegate void Click();
        private async void open_record(DownloadRecord record){
            if(!app.downloads.owns(record,session) || !record.may_open)return;
            if(record.risky_to_open()){
                var alert=new Adw.AlertDialog(_("Open Downloaded Software?"),_("This file may run code or install software. It may be harmful even if a scan finds no threat. Open it only if you trust its source."));
                alert.add_response("cancel",_("Cancel"));alert.add_response("open",_("Open"));alert.close_response="cancel";alert.default_response="cancel";alert.set_response_appearance("open",Adw.ResponseAppearance.DESTRUCTIVE);
                if((yield alert.choose(this,null))!="open")return;
            }
            if(app.downloads.owns(record,session) && record.may_open)yield launch(record.destination,false);
        }
        private Gtk.Button add_button(Adw.ActionRow row,string label,owned Click click){var button=new Gtk.Button.with_label(label);button.valign=Gtk.Align.CENTER;button.clicked.connect(()=>click());row.add_suffix(button);return button;}
        private async void launch(string path,bool folder){try{var file=File.new_for_path(path);if(!file.query_exists())throw new IOError.NOT_FOUND(_("The downloaded file no longer exists."));var launcher=new Gtk.FileLauncher(file);if(folder)yield launcher.open_containing_folder(null,null);else yield launcher.launch(null,null);}catch(Error e){EngineDialogs.show_error(this,e.message);}}
    }
}
