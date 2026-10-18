namespace MajorisBrowser {
    public class BrowsingDataDialog : Adw.AlertDialog {
        private Application app;
        private MajorisCef.View? engine;
        private Gtk.CheckButton history=new Gtk.CheckButton.with_label(_("Browsing history"));
        private Gtk.CheckButton downloads=new Gtk.CheckButton.with_label(_("Download records (keeps downloaded files; active downloads remain)"));
        private Gtk.CheckButton cookies=new Gtk.CheckButton.with_label(_("All Browser cookies"));
        private Gtk.CheckButton cache=new Gtk.CheckButton.with_label(_("HTTP cache"));
        private Gtk.CheckButton permissions=new Gtk.CheckButton.with_label(_("Browser site permissions"));
        private Gtk.CheckButton addresses=new Gtk.CheckButton.with_label(_("Saved address profiles"));
        private Gtk.DropDown range=new Gtk.DropDown.from_strings({_("All Time"),_("Last Hour"),_("Last 24 Hours"),_("Last 7 Days")});
        private int pending;
        private bool running;
        private string failure="";
        private ulong handler;
        private uint timeout;
        public BrowsingDataDialog(Application app){
            Object(heading:_("Clear Browser Data"),body:_("The time range applies to history and download records only. Other selected categories are cleared for all time. Saved passwords and installed-app data are retained."));this.app=app;
            foreach(var window in app.get_windows()){var browser=window as BrowserWindow;if(browser!=null && browser.browsing_engine()!=null){engine=browser.browsing_engine();break;}}
            var box=new Gtk.Box(Gtk.Orientation.VERTICAL,8);box.append(range);foreach(var check in new Gtk.CheckButton[]{history,downloads,cookies,cache,permissions,addresses})box.append(check);history.active=true;
            cookies.sensitive=cache.sensitive=engine!=null;if(engine==null){var notice=new Gtk.Label(_("Open a normal Browser window to clear engine cookies or cache."));notice.wrap=true;box.append(notice);}
            var storage=new Gtk.Label(_("For all site storage and partitions, use Clear Browser Cookies and Site Data in Settings. That operation closes Browser and clears its entire engine profile."));storage.wrap=true;box.append(storage);extra_child=box;
            add_response("cancel",_("Cancel"));add_response("clear",_("Clear Selected Data"));set_response_appearance("clear",Adw.ResponseAppearance.DESTRUCTIVE);close_response="cancel";
            response.connect((id)=>{if(id=="clear")clear_selected();});
        }
        private void complete(string? error=null){
            if(!running)return;if(error!=null)failure+=(failure==""?"":"\n")+error;
            if(--pending>0)return;running=false;if(timeout!=0){Source.remove(timeout);timeout=0;}if(engine!=null && handler!=0){engine.disconnect(handler);handler=0;}
            if(app.active_window!=null){var dialog=new Adw.AlertDialog(failure==""?_("Selected Data Cleared"):_("Some Data Could Not Be Cleared"),failure==""?_("Downloaded files, saved passwords and installed-app data were retained."):failure);dialog.add_response("close",_("Close"));dialog.present(app.active_window);}app.release();
        }
        private void clear_selected(){
            if(running || app.webapp!=null)return;running=true;app.hold();
            bool h=history.active,p=permissions.active,a=addresses.active,c=cookies.active,k=cache.active,d=downloads.active;
            int64[] seconds={0,3600,86400,604800};int64 since=range.selected==0?0:new DateTime.now_utc().to_unix()-seconds[range.selected];
            pending=1+(c?1:0)+(k?1:0);failure="";
            if(engine!=null && (c || k)){
                handler=engine.event.connect((kind,value)=>{
                    if(!running)return;
                    if(c && kind=="operation-complete" && value=="clear-browser-cookies"){c=false;complete();}
                    if(k && kind=="operation-complete" && value=="clear-http-cache"){k=false;complete();}
                    if(kind=="closed" || (kind=="operation-error" && (value=="clear-cookies" || value=="clear-http-cache"))){if(c){c=false;complete(_("Cookie clearing did not complete."));}if(k){k=false;complete(_("Cache clearing did not complete."));}}
                });
                timeout=Timeout.add_seconds(20,()=>{timeout=0;if(c){c=false;complete(_("Cookie clearing timed out."));}if(k){k=false;complete(_("Cache clearing timed out."));}return Source.REMOVE;});
                if(c)engine.clear_cookies();if(k)engine.clear_http_cache();
            }
            app.storage.run((store)=>{
                string? error=null;try{store.clear_browser_records(h,p,a,since,d);}catch(Error e){error=e.message;}
                Idle.add(()=>{if(error==null){if(p)app.permissions.reload();if(d)app.downloads.clear_history(since);}complete(error);return Source.REMOVE;});
            });
        }
    }
}
