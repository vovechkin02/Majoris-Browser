namespace MajorisBrowser {
    public class SessionService : Object {
        private Application app;
        private uint debounce;
        private int64 generation=GLib.get_real_time();
        private string last_state="[]";
        public bool restoring;
        public bool closing_all;
        public SessionService(Application app){this.app=app;}
        public void changed(){
            if(restoring || app.webapp!=null)return;
            if(debounce!=0)Source.remove(debounce);
            debounce=Timeout.add(500,()=>{debounce=0;save(false);return Source.REMOVE;});
        }
        public void save(bool clean,BrowserWindow? exclude=null){
            if(closing_all && !clean)return;
            var builder=new Json.Builder();builder.begin_array();int count=0,history_budget=16*1024*1024;
            foreach(var window in app.get_windows()){
                var browser=window as BrowserWindow;if(browser==null || browser.private_mode || browser==exclude)continue;
                builder.add_value(browser.export_state(ref history_budget));count++;
            }
            if(count==0 && exclude!=null && !exclude.private_mode){builder.add_value(exclude.export_state(ref history_budget));count++;}
            builder.end_array();
            if(count>0){var generator=new Json.Generator();generator.set_root(builder.get_root());last_state=generator.to_data(null);}
            if(last_state=="[]")return;
            generation=int64.max(generation+1,GLib.get_real_time());int64 version=generation;string data=last_state;
            app.storage.run((store)=>store.snapshot(version,data,clean));
        }
        public void stop(){if(debounce!=0){Source.remove(debounce);debounce=0;}save(true);}
        public void begin_shutdown(){save(true);closing_all=true;}
        public void restore(string data){
            restoring=true;
            try{
                var parser=new Json.Parser();parser.load_from_data(data);var windows=parser.get_root().get_array();
                BrowserWindow? active=null;
                foreach(var node in windows.get_elements()){
                    var window=new BrowserWindow(app,false,false);window.import_state(node.get_object());window.present();
                    if(node.get_object().has_member("active-window") && node.get_object().get_boolean_member("active-window"))active=window;
                }
                if(active!=null)active.present();
                last_state=data;
            }catch(Error e){new BrowserWindow(app,false).present();}
            restoring=false;changed();
        }
    }
}
